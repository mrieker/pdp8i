//    Copyright (C) Mike Rieker, Beverly, MA USA
//    www.outerworldapps.com
//
//    This program is free software; you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation; version 2 of the License.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    EXPECT it to FAIL when someone's HeALTh or PROpeRTy is at RISk.
//
//    You should have received a copy of the GNU General Public License
//    along with this program; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//    http://www.gnu.org/licenses/gpl-2.0.html

// operate pidp panel via gpio connector or tcp connection to raspi plugged into pidp panel

// if using remote pidp panel,
//  on remote raspi: ./pidptcpserver
//  on client:  export pidptcpaddr=<hostname of remote raspi>

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include "pidp.h"
#include "z8iutil.h"

// gpio pins

#define COLMASK 0xFFF0

#define SWROW1  16
#define SWROW2  17
#define SWROW3  18

#define LEDROW1 20
#define LEDROW2 21
#define LEDROW3 22
#define LEDROW4 23
#define LEDROW5 24
#define LEDROW6 25
#define LEDROW7 26
#define LEDROW8 27

// directions

// - https://www.raspberrypi.org/documentation/hardware/raspberrypi/gpio/gpio_pads_control.md
//   111... means 2mA; 777... would be 14mA

#define IGO 1

// - when writing LEDs
//   all switch rows set to inputs (hi-Z)
//   led row select outputs are active high (just one at a time)
//   column outputs are active low

#define LEDSEL0 (IGO*01111110000)   // GPIO[09:00]
#define LEDSEL1 (IGO*00000111111)   // GPIO[19:10]
#define LEDSEL2 (IGO*00011111111)   // GPIO[29:20]

// - when reading switches
//   switch row select outputs are active low (just one at a time)
//   column inputs are active low

#define SWSEL0  (IGO*00000000000)   // GPIO[09:00]
#define SWSEL1  (IGO*00111000000)   // GPIO[19:10]
#define SWSEL2  (IGO*00011111111)   // GPIO[29:20]

#define GPIO_FSEL0 (0)          // set output current / disable (readwrite)
#define GPIO_SET0 (0x1C/4)      // set gpio output bits (writeonly)
#define GPIO_CLR0 (0x28/4)      // clear gpio output bits (writeonly)
#define GPIO_LEV0 (0x34/4)      // read gpio bit levels (readonly)
#define GPIO_PUDMOD (0x94/4)    // pullup/pulldown enable (0=disable; 1=enable pulldown; 2=enable pullup)
#define GPIO_PUDCLK (0x98/4)    // which pins to change pullup/pulldown mode

static uint16_t const swmasks[3] = { 0xFFF0, 0xC0F0, 0xC3F0 };

static int buttonindex;
static int gpiotcpfd = -1;
static struct sockaddr_in gpiotcpsa;
static uint32_t buttonring[8];
static uint32_t rdcychz;    // actually cycles/0.131072sec
static uint32_t volatile *gpiopage;

static void reconnect ();
static void *gpioopen (char const *devname);
static uint32_t getnowns ();
static void waitus (uint32_t us);
static void set_mode_output (uint32_t bits);
static void set_mode_input (uint32_t bits);
static void set_output_high (uint32_t bits);
static void set_output_low (uint32_t bits);

// open access to gpio
void pidp_open (char const *server)
{
    if (server != NULL) {

        // set up server address and port number
        gpiotcpsa.sin_family = AF_INET;
        gpiotcpsa.sin_port = htons (pidptcpport);
        if (!inet_aton (server, &gpiotcpsa.sin_addr)) {
            struct hostent *he = gethostbyname (server);
            if (he == NULL) {
                fprintf (stderr, "pidp_proc: bad server address %s\n", server);
                ABORT ();
            }
            if ((he->h_addrtype != AF_INET) || (he->h_length != 4)) {
                fprintf (stderr, "pidp_proc: server %s not IP v4\n", server);
                ABORT ();
            }
            gpiotcpsa.sin_addr = *(struct in_addr *)he->h_addr;
        }

        reconnect ();
    } else {

        // not using TCP, access gpio pins directly
        gpiopage = (uint32_t volatile *) gpioopen ("/dev/gpiomem");
        set_mode_input  (0xFF7FFF0U);   // set all pins we work with to inputs
        set_output_low  (0xFF00000U);   // lamp selects are active high
        set_output_high (0x0070000U);   // switch selects are active low
        set_mode_output (0xFF70000U);   // set lamp & switch select lines to output
        for (int i = 4; i < 16; i ++) { // put pullups on data pins for reading switches
            gpiopage[GPIO_PUDMOD] = 2;  // 1=pulldown; 2=pullup
            usleep (10);
            gpiopage[GPIO_PUDCLK] = 1U << i;
            usleep (10);
            gpiopage[GPIO_PUDMOD] = 0;
            usleep (10);
            gpiopage[GPIO_PUDCLK] = 0;
            usleep (10);
        }

        // stay on CPU 0 so rdcyc() will work
        cpu_set_t cpuset;
        CPU_ZERO (&cpuset);
        CPU_SET (0, &cpuset);
        if (sched_setaffinity (0, sizeof cpuset, &cpuset) < 0) {
            ABORT ();
        }

        // read rdcyc() frequency
#if 000
        uint32_t startcyc = rdcyc ();
        uint32_t startns  = getnowns ();
        uint32_t stopcyc, stopns;
        do {
            stopcyc = rdcyc ();
            stopns  = getnowns ();
        } while (stopns - startns < 131072000);
        rdcychz = stopcyc - startcyc;
#else
        rdcychz = getnowns ();
#endif
    }
}

// send LEDs to PiDP panel, read switches from PiDP panel
bool pidp_proc (PiDPMsg *pidpmsg)
{
    if (gpiopage != NULL) {

        // set data pins to output mode
        set_mode_output (0xFFF0U);

        // output LED rows
        for (int i = 0; i < 8; i ++) {

            // output lamp data (active low)
            uint32_t ledrow = pidpmsg->ledrows[i];
            set_output_high (0xFFF0U & ~ ledrow);
            set_output_low  (0xFFF0U &   ledrow);

            // select lamp row (active high)
            set_output_high (0x100000U << i);

            // let light soak into eyeballs
            usleep (200);

            // deselect lamp row then let it soak in
            set_output_low (0xFF00000U);
            waitus (5);
        }

        // set data pins to input
        set_mode_input (0xFFF0U);

        // read switch rows
        for (int i = 0; i < 3; i ++) {
            set_output_low  (0x10000U << i);
            waitus (3);
            pidpmsg->swrows[i] = swmasks[i] & ~ gpiopage[GPIO_LEV0];
            set_output_high (0x70000U);
        }

        // debounce button row
        buttonring[buttonindex] = pidpmsg->swrows[2];
        buttonindex = (buttonindex + 1) % 8;
        for (int i = 0; i < 8; i ++) {
            pidpmsg->swrows[2] &= buttonring[i];
        }
    } else {
        PiDPMsg recvbuf;
        while (true) {
            int rc = write (gpiotcpfd, pidpmsg, sizeof *pidpmsg);
            if (rc != (int) sizeof *pidpmsg) {
                if (rc < 0) {
                    fprintf (stderr, "pidp_proc: error writing to server: %m\n");
                } else {
                    fprintf (stderr, "pidp_proc: only wrote %d bytes of %d\n", rc, (int) sizeof *pidpmsg);
                }
            } else {

                // read in reply
                rc = read (gpiotcpfd, &recvbuf, sizeof recvbuf);
                if (rc == (int) sizeof recvbuf) break;
                if (rc < 0) {
                    fprintf (stderr, "pidp_proc: error reading from server: %m\n");
                } else {
                    fprintf (stderr, "pidp_proc: only read %d bytes of %d\n", rc, (int) sizeof recvbuf);
                }
            }
            close (gpiotcpfd);
            reconnect ();
        }

        // return the switch values
        memcpy (pidpmsg->swrows, recvbuf.swrows, sizeof pidpmsg->swrows);
    }

    return true;
}

static void reconnect ()
{
    // create tcp socket
    gpiotcpfd = socket (AF_INET, SOCK_STREAM, 0);
    if (gpiotcpfd < 0) ABORT ();

    // timeout after 5 seconds trying to connect
    static unsigned const timeoutms = 5000;
    if (setsockopt (gpiotcpfd, IPPROTO_TCP, TCP_USER_TIMEOUT, &timeoutms, sizeof timeoutms) < 0) ABORT ();

    // connect to server port
    int lasterr = 0;
    while (connect (gpiotcpfd, (struct sockaddr *) &gpiotcpsa, sizeof gpiotcpsa) < 0) {
        int err = errno;
        if (err != lasterr) {
            fprintf (stderr, "pidp_proc: error connecting to %s:%d: %m\n",
                inet_ntoa (gpiotcpsa.sin_addr), ntohs (gpiotcpsa.sin_port));
            lasterr = err;
        }
        if (err != ETIMEDOUT) {
            usleep (timeoutms * 1000);
        }
    }

    fprintf (stderr, "pidp_proc: connected to %s:%d\n",
        inet_ntoa (gpiotcpsa.sin_addr), ntohs (gpiotcpsa.sin_port));
}

static void *gpioopen (char const *devname)
{
    // access gpio page in physical memory
    int memfd = ::open (devname, O_RDWR);
    if (memfd < 0) {
        fprintf (stderr, "GpioFile::open: error opening %s: %m\n", devname);
        ABORT ();
    }

    // make sure another copy isn't running
    while (true) {
        struct flock flockit;
        memset (&flockit, 0, sizeof flockit);
        flockit.l_type   = F_WRLCK;
        flockit.l_whence = SEEK_SET;
        flockit.l_len    = 4096;
        if (fcntl (memfd, F_SETLK, &flockit) >= 0) break;
        if (((errno != EACCES) && (errno != EAGAIN)) || (fcntl (memfd, F_GETLK, &flockit) < 0)) {
            fprintf (stderr, "error locking %s: %m\n", devname);
            ABORT ();
        }
        if (flockit.l_type != F_UNLCK) {
            fprintf (stderr, "error locking %s: locked by pid %d\n", devname, (int) flockit.l_pid);
            ABORT ();
        }
    }

    // access the page
    void *memptr = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, 0);
    if (memptr == MAP_FAILED) {
        fprintf (stderr, "error mmapping %s: %m\n", devname);
        ABORT ();
    }

    return memptr;
}

// read current time in nanoseconds
static uint32_t getnowns ()
{
    struct timespec nowts;
    if (clock_gettime (CLOCK_MONOTONIC, &nowts) < 0) ABORT ();
    return nowts.tv_sec * 1000000000ULL + nowts.tv_nsec;
}

// wait (via loop) at least the given number of microseconds
static void waitus (uint32_t us)
{
#if 000
    uint32_t waitfor = us * rdcychz / 131072;
    uint32_t start = rdcyc ();
    uint32_t delta;
    do delta = rdcyc () - start;
    while (delta < waitfor);
#else
    usleep (us);
#endif
}

// set given gpio pins to output mode
static void set_mode_output (uint32_t bits)
{
    for (int i = 0; i < 3; i ++) {
        uint32_t fsel = gpiopage[GPIO_FSEL0+i];
        for (int b = 0; b < 10; b ++) {
            if (bits & 1) fsel |= IGO << (b * 3);
            bits >>= 1;
        }
        gpiopage[GPIO_FSEL0+i] = fsel;
    }
}

// set given gpio pins to input mode
static void set_mode_input (uint32_t bits)
{
    for (int i = 0; i < 3; i ++) {
        uint32_t fsel = gpiopage[GPIO_FSEL0+i];
        for (int b = 0; b < 10; b ++) {
            if (bits & 1) fsel &= ~ (7 << (b * 3));
            bits >>= 1;
        }
        gpiopage[GPIO_FSEL0+i] = fsel;
    }
}

// set given gpio output pins to high (3.3V)
static void set_output_high (uint32_t bits)
{
    gpiopage[GPIO_SET0] = bits;
}

// set given gpio output pins to low (0V)
static void set_output_low (uint32_t bits)
{
    gpiopage[GPIO_CLR0] = bits;
}
