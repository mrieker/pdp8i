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

// daemon for verilator zynq simulator
// run on x86_64 as daemon - ./verizynq.x86_64 &
// ...will show output from $display() calls in verilog
// then run z8ipanel, z8idump, z8iila, etc on same x86_64
// first use of z8ipanel must include -sim option to put in simulator mode

// $ ./verizynq.x86_64 &

// $ cd ../demos
// $ ../ccode/z8ipanel -sim doubleroll.tcl
//    takes 40 sec to start loading
//    takes 10 mins to complete loading and verify
// $ ../ccode/z8ipanel -status
//    takes a minute to copy itself to all fields
//    takes 10 sec per step

// stop any verizynq that might be runnung
// $ ./verizynq.x86_64 -stop

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <unistd.h>

#define ABORT() do { fprintf (stderr, "ABORT %s %d\n", __FILE__, __LINE__); abort (); } while (0)

#include "obj_dir/VZynq.h"

#include "futex.h"
#include "verizynq.h"

static VZynq *vzynq;

static void kerchunk ();

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    bool stop = false;
    for (int i = 0; ++ i < argc;) {
        if (strcasecmp (argv[i], "-stop") == 0) stop = true;
    }

    int shmfd = shm_open (VERIZYNQ_SHMNM, O_RDWR | O_CREAT, 0666);
    if (shmfd < 0) {
        fprintf (stderr, "verizynq: error creating %s: %m\n", VERIZYNQ_SHMNM);
        ABORT ();
    }

    VeriPage volatile *pageptr;

    if (ftruncate (shmfd, sizeof *pageptr) < 0) {
        fprintf (stderr, "verizynq: error truncating %s: %m\n", VERIZYNQ_SHMNM);
        ABORT ();
    }

    int kills = 3;
    while (true) {
        struct flock flockit;
        memset (&flockit, 0, sizeof flockit);
        flockit.l_type   = F_WRLCK;
        flockit.l_whence = SEEK_SET;
        flockit.l_len    = sizeof *pageptr;
        if (fcntl (shmfd, F_SETLK, &flockit) >= 0) break;

        // failed, try to find out what pid has it locked
        if (((errno == EACCES) || (errno == EAGAIN)) && (fcntl (shmfd, F_GETLK, &flockit) >= 0)) {
            if (flockit.l_type == F_UNLCK) continue;

            // print out message saying pid that has it locked
            fprintf (stderr, "verizynq: %s locked by pid %d\n", VERIZYNQ_SHMNM, (int) flockit.l_pid);
            if (-- kills >= 0) {

                // try to kill it then try locking again
                fprintf (stderr, "verizynq: killing pid %d\n", (int) flockit.l_pid);
                kill ((int) flockit.l_pid, SIGTERM);
                usleep (125000);
                continue;
            }
        } else {
            fprintf (stderr, "verizynq: error locking %s: %m\n", VERIZYNQ_SHMNM);
        }
        ABORT ();
    }

    if (stop) return 0;

    void *ptr = mmap (NULL, sizeof *pageptr, PROT_READ | PROT_WRITE, MAP_SHARED, shmfd, 0);
    if (ptr == MAP_FAILED) {
        fprintf (stderr, "verizynq: error mmapping %s: %m\n", VERIZYNQ_SHMNM);
        ABORT ();
    }
    memset (ptr, 0, sizeof *pageptr);
    pageptr = (VeriPage volatile *) ptr;
    pageptr->serverpid = getpid ();
    fprintf (stderr, "verizynq: pid %d\n", pageptr->serverpid);

    // run a few cycles with power-on reset asserted
    VZynq vzynqobj;
    vzynq = &vzynqobj;
    vzynq->RESET_N = 0;
    for (int i = 0; i < 10; i ++) {
        kerchunk ();
    }
    vzynq->RESET_N = 1;
    for (int i = 0; i < 10; i ++) {
        kerchunk ();
    }

    char const *env = getenv ("verimain_debug");
    int debug = (env == NULL) ? 0 : atoi (env);

    while (true) {
        int state = pageptr->state;
        switch (state & VERIZYNQ_STATE) {

            // maybe client aborted during request
            case VERIZYNQ_BUSY:
            case VERIZYNQ_DONE: {
                if (kill (state & VERIZYNQ_CPID, 0) < 0) {
                    fprintf (stderr, "verizynq: client %d died\n", state & VERIZYNQ_CPID);
                    if (! atmcmpxchg (&pageptr->state, state, VERIZYNQ_IDLE)) ABORT ();
                    if (futex (&pageptr->state, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0) ABORT ();
                }
                kerchunk ();
                break;
            }

            // some client wants to read one of the arm-side registers
            case VERIZYNQ_READ: {
                uint32_t index = pageptr->index;
                if (index > 1023) ABORT ();

                // send read address out over AXI bus and say we are ready to accept read data
                vzynq->saxi_ARADDR  = index * sizeof pageptr->value;
                vzynq->saxi_ARVALID = 1;
                vzynq->saxi_RREADY  = 1;

                // keep kerchunking until both transfers have completed
                // capture read data on cycle where both RREADY and RVALID are set
                // transfer happens on posedge CLOCK when both VALID and READY are set
                for (int i = 0; vzynq->saxi_ARVALID | vzynq->saxi_RREADY; i ++) {
                    if (i > 10) ABORT ();
                    bool arready = vzynq->saxi_ARREADY;     // zynq.v says it can accept address
                    bool rvalid  = vzynq->saxi_RVALID;      // zynq.v says it is driving RDATA
                    if (rvalid & vzynq->saxi_RREADY) {      // ...and we have not accepted it yet
                        pageptr->value = vzynq->saxi_RDATA; // if so, grab data from zynq.v

                        if (debug > 1) printf ("verizynq:  read %03X > %08X\n", index, pageptr->value);

                        if (! atmcmpxchg (&pageptr->state, state, VERIZYNQ_DONE ^ VERIZYNQ_READ ^ state)) ABORT ();
                        if (futex (&pageptr->state, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0) ABORT ();
                    }
                    kerchunk ();                            // zynq.v clocks in address when it sees both ARREADY and
                                                            //  ARVALID asserted just before posedge CLOCK then it
                                                            //  negates ARREADY just after posedge CLOCK
                                                            // when it sees RREADY asserted just before posedge
                                                            //  CLOCK, it asserts RVALID and drives RDATA just after
                                                            //  posedge CLOCK.
                                                            // when it sees both RREADY and RVALID asserted just
                                                            //  before posedge CLOCK, it knows we got the data, so it
                                                            //  negates RVALID just after posedge CLOCK.
                    if (arready) vzynq->saxi_ARVALID = 0;   // if zynq.v clocked in address, stop sending it so it
                                                            //  doesn't start another read cycle
                    if (rvalid)  vzynq->saxi_RREADY  = 0;   // zynq.v sent read data so stop waiting for it
                }
                break;
            }

            // some client wants to write one of the arm-side registers
            case VERIZYNQ_WRITE: {
                uint32_t index = pageptr->index;
                if (index > 1023) ABORT ();

                // put address and write data on AXI bus
                // say they are valid and also we are ready to accept write acknowledge
                vzynq->saxi_AWADDR  = index * sizeof pageptr->value;
                vzynq->saxi_AWVALID = 1;
                vzynq->saxi_WDATA   = pageptr->value;
                vzynq->saxi_WVALID  = 1;
                vzynq->saxi_BREADY  = 1;

                if (debug > 0) printf ("verizynq: write %03X < %08X\n", index, pageptr->value);

                if (! atmcmpxchg (&pageptr->state, state, VERIZYNQ_DONE ^ VERIZYNQ_WRITE ^ state)) ABORT ();
                if (futex (&pageptr->state, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0) ABORT ();

                // keep kerchunking until all 3 transfers have completed
                // transfer happens on posedge CLOCK when both VALID and READY are set
                for (int i = 0; vzynq->saxi_AWVALID | vzynq->saxi_WVALID | vzynq->saxi_BREADY; i ++) {
                    if (i > 10) ABORT ();
                    bool awready = vzynq->saxi_AWREADY;     // zynq.v says it can accept address
                    bool wready  = vzynq->saxi_WREADY;      // zynq.v says it can accept data
                    bool bvalid  = vzynq->saxi_BVALID;      // zynq.v says it has completed the write
                    kerchunk ();                            // zynq.v clocks in address when it sees both AWREADY and
                                                            //  AWVALID asserted just before posedge CLOCK then it
                                                            //  negates AWREADY just after posedge CLOCK
                                                            // likewise for WREADY and WVALID
                                                            // it asserts BVALID just after posedge CLOCK.
                                                            //  when it sees both BREADY and BVALID asserted just
                                                            //  before posedge CLOCK, it negates BVALID just after
                                                            //  posedge CLOCK.
                    if (awready) vzynq->saxi_AWVALID = 0;   // zynq.v clocked in address so stop sending it
                    if (wready)  vzynq->saxi_WVALID  = 0;   // zynq.v clocked in data so stop sending it
                    if (bvalid)  vzynq->saxi_BREADY  = 0;   // zynq.v finished write so stop waiting for it
                }
                break;
            }

            // no client waiting for something, just keep clocking processor
            default: {
                kerchunk ();
                break;
            }
        }

        // if arm interrupt bit set, wake anything that's waiting for a set bit
        uint32_t oldirqmsk = pageptr->armintmsk;
        uint32_t newirqmsk = vzynq->zgintflags;
        pageptr->armintmsk = newirqmsk;
        if ((debug > 0) && (oldirqmsk != newirqmsk)) printf ("verizynq: armirqmsk %08X\n", newirqmsk);
        if ((newirqmsk & ~ oldirqmsk) &&
                (futex ((int *) &pageptr->armintmsk, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0)) {
            ABORT ();
        }
    }
}

// call with clock still low and input signals just changed
// returns with output signals updated and clock just set low
static void kerchunk ()
{
    vzynq->eval ();    // let input signals soak in
    vzynq->CLOCK = 1;  // clock the state
    vzynq->eval ();    // let new state settle in
    vzynq->CLOCK = 0;  // get ready for more input changes
}
