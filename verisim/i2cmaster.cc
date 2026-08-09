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

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "i2cmaster.h"

static void opengpio ();
static void setbus (int bus);
static void waithalf ();
static void setclock (bool val);
static void setdata (bool val);
static bool getdata ();

#define SPEED 12    // works for PI-Zero-2

#define SDA1 0      // GPIO bits
#define SCK1 1
#define SDA2 2
#define SCK2 3

#define RESET 23

#define CLOCKMASK1  (1U << SCK1)
#define DATAMASK1   (1U << SDA1)
#define DATADIRIN1  (1U << (3 * SCK1))
#define DATADIROUT1 (DATADIRIN1 | (1U << (3 * SDA1)))

#define CLOCKMASK2  (1U << SCK2)
#define DATAMASK2   (1U << SDA2)
#define DATADIRIN2  (1U << (3 * SCK2))
#define DATADIROUT2 (DATADIRIN2 | (1U << (3 * SDA2)))

static uint32_t clockmask;
static uint32_t datamask;
static uint32_t datadirin;
static uint32_t datadirout;
static uint32_t volatile *gpiopage;



// Act as master of I2C bus
//  inputs:
//   command[63:62] = 00: done; 01: restart; 10: read; 11: write [61:54]
//     10: shifts 8 bits from i2c bus into bottom of status register
//     11: followed by 8 bits to send to i2c bus
// outputs:
//   return 0: success
//         -1: nak
//         -2: data bit stuck on 0 to begin with
//         -3: data bit stuck on 0 to begin with
//   *readdata = any read bytes shifted into bottom bits
int i2cmaster (int bus, uint64_t command, uint64_t *readdata)
{
    if (gpiopage == NULL) {
        opengpio ();
    }
    setbus (bus);

    // send out start bit, starts with clock and data both high
    // wait 5uS, data down
    // wait 5uS, clock down
    waithalf ();
    if (! getdata ()) return -2;
    setdata  (0);
    waithalf ();
    setclock (0);
    waithalf ();

    int rc = 0;

    while (true) {

        // 00: done; 01: restart; 10: read; 11: write [61:54]
        uint8_t cmd = command >> 62;
        command <<= 2;
        switch (cmd) {
            case I2CST: goto done;

            // send restart bit
            // clock and data both zero to start
            // wait 5uS, data up
            // wait 5uS, clock up
            // wait 5uS, data down
            // wait 5uS, clock down
            // wait 5uS, done
            case I2CRS: {
                waithalf ();
                setdata  (1);
                waithalf ();
                setclock (1);
                waithalf ();
                setdata  (0);
                waithalf ();
                setclock (0);
                waithalf ();
                break;
            }

            // read byte
            // data up (to open-drain data line)
            // repeat 8 times:
            //  wait 5uS, clock up
            //  wait 5uS, shift in data bits 7..0, clock down
            //    (clock down tells 23017 to send out next bit)
            // wait 5uS, another read next ? data down : data up
            // wait 5uS, clock up
            // wait 5uS, clock down
            // wait 5uS, done
            case I2CRD: {
                waithalf ();
                setdata  (1);
                uint8_t data = 0;
                for (int i = 0; i < 8; i ++) {
                    waithalf ();
                    setclock (1);
                    waithalf ();
                    data += data + getdata ();
                    setclock (0);
                }
                setdata  ((command >> 62) != 2);
                waithalf ();
                setclock (1);
                waithalf ();
                setclock (0);
                waithalf ();
                setdata  (0);
                waithalf ();
                *readdata = (*readdata << 8) | data;
                break;
            }

            // clock and count both zero to start
            // data is data bit 7 to start
            //  wait 5uS,  clock up
            // repeat 7 times:
            //  wait 5uS,  clock down
            //  wait 50nS, send data bits 6..0
            //  wait 4.95uS, clock up
            // wait 5uS, clock down
            // wait 5uS, data up to open-drain data line
            // wait 5uS, clock up
            // wait 5uS, data high (no ack) means error
            //           clock down
            // wait 5uS, data down
            //           done (stop if error, else next command)
            case I2CWR: {
                for (int i = 0; i < 8; i ++) {
                    waithalf ();
                    setdata ((command >> 63) & 1);
                    command <<= 1;
                    waithalf ();
                    setclock (1);
                    waithalf ();
                    setclock (0);
                }
                waithalf ();
                setdata  (1);
                waithalf ();
                setclock (1);
                waithalf ();
                bool nak = getdata ();
                setclock (0);
                waithalf ();
                setdata  (0);
                waithalf ();
                if (nak) {
                    rc = -1;
                    goto done;
                }
                break;
            }
        }
    }

done:;
    // send stop bit
    // clock and data all zero to start
    // wait 5uS, clock up
    // wait 5uS, data up
    // wait 5uS, done
    waithalf ();
    setclock (1);
    waithalf ();
    setdata  (1);
    waithalf ();
    if (! getdata ()) rc = -3;

    return rc;
}


#define IGO 1

#define GPIO_FSEL0 (0)          // set output current / disable (readwrite)
#define GPIO_SET0 (0x1C/4)      // set gpio output bits (writeonly)
#define GPIO_CLR0 (0x28/4)      // clear gpio output bits (writeonly)
#define GPIO_LEV0 (0x34/4)      // read gpio bit levels (readonly)
#define GPIO_PUDMOD (0x94/4)    // pullup/pulldown enable (0=disable; 1=enable pulldown; 2=enable pullup)
#define GPIO_PUDCLK (0x98/4)    // which pins to change pullup/pulldown mode

static void opengpio ()
{
    // access gpio page in physical memory
    int memfd = ::open ("/dev/gpiomem", O_RDWR | O_SYNC);
    if (memfd < 0) {
        fprintf (stderr, "i2cmaster: error opening /dev/gpiomem: %m\n");
        abort ();
    }

    // lock exclusive access to gpio page
trylk:;
    struct flock flockit;
    memset (&flockit, 0, sizeof flockit);
    flockit.l_type   = F_WRLCK;
    flockit.l_whence = SEEK_SET;
    flockit.l_len    = 4096;
    if (fcntl (memfd, F_SETLK, &flockit) < 0) {
        if (((errno == EACCES) || (errno == EAGAIN)) && (fcntl (memfd, F_GETLK, &flockit) >= 0)) {
            if (flockit.l_type == F_UNLCK) goto trylk;
            fprintf (stderr, "i2cmaster: error locking /dev/gpiomem: locked by pid %d\n", (int) flockit.l_pid);
        }  else {
            fprintf (stderr, "i2cmaster: error locking /dev/gpiomem: %m\n");
        }
        abort ();
    }

    // make pointer to gpio register page
    void *memptr = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, memfd, 0);
    if (memptr == MAP_FAILED) {
        fprintf (stderr, "i2cmaster: error mmapping /dev/gpiomem: %m\n");
        abort ();
    }
    gpiopage = (uint32_t volatile *) memptr;

    // https://www.raspberrypi.org/documentation/hardware/raspberrypi/gpio/gpio_pads_control.md
    // 111... means 2mA; 777... would be 14mA

    gpiopage[GPIO_SET0] = 0xFFFFFFFF;
    gpiopage[GPIO_FSEL0+0] = DATADIRIN1 | DATADIRIN2;   // gpio<09:00> = 
    gpiopage[GPIO_FSEL0+1] = 0;                         // gpio<19:10> = unused
    gpiopage[GPIO_FSEL0+2] = 1U << (3 * (RESET - 20));  // gpio<23> = reset
    gpiopage[GPIO_SET0] = 0xFFFFFFFF;
    usleep (100);
    gpiopage[GPIO_CLR0] = 1 << RESET;                   // release reset, leave clock and data high
    usleep (100);
}

static void setbus (int bus)
{
    switch (bus) {
        case 1: {
            clockmask  = CLOCKMASK1;
            datamask   = DATAMASK1;
            datadirin  = DATADIRIN1  | DATADIRIN2;
            datadirout = DATADIROUT1 | DATADIRIN2;
            break;
        }
        case 2: {
            clockmask  = CLOCKMASK2;
            datamask   = DATAMASK2;
            datadirin  = DATADIRIN2  | DATADIRIN1;
            datadirout = DATADIROUT2 | DATADIRIN1;
            break;
        }
        default: abort ();
    }
}

// wait half a clock cycle
static void waithalf ()
{
    for (int i = SPEED; -- i >= 0;) {
        gpiopage[GPIO_LEV0];
    }
}

// set clock line to given value
static void setclock (bool val)
{
    gpiopage[val?GPIO_SET0:GPIO_CLR0] = clockmask;
}

// set data line to given value
//  high sets it to input mode
//  low sets it to output mode
static void setdata (bool val)
{
    if (val) {
        gpiopage[GPIO_CLR0]  = 0;
        gpiopage[GPIO_SET0]  = datamask;
        gpiopage[GPIO_FSEL0] = datadirin;
    } else {
        gpiopage[GPIO_FSEL0] = datadirout;
        gpiopage[GPIO_SET0]  = 0;
        gpiopage[GPIO_CLR0]  = datamask;
    }
}

// get data line value
static bool getdata ()
{
    return (gpiopage[GPIO_LEV0] & datamask) != 0;
}
