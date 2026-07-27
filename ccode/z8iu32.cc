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

// Running z8i utilities on a PC - the Zynq register page is simulated using a 4K shared memory page.
// Reads and Writes are wrapped with calls to veriread() and veriwrite().
// The Zynq code is run in verilator daemon process verizynq.

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "futex.h"
#include "verizynq.h"
#include "z8iutil.h"

static int mypid, serverpid;
static int shmfd = -1;
static Z8IU32 *nullpage;
static VeriPage *pageptr;

static void waitforidle ();
static uint32_t waitfordone (int func);
static void futexwait (int *cell, int valu);

void *Z8IU32::veriopen (int *fd_r)
{
    *fd_r = -1;
    if (nullpage == NULL) {

        // pid must fit in low 29 bits of pageptr->state
        mypid = getpid ();
        if ((mypid & VERIZYNQ_CPID) != mypid) ABORT ();

        // access VeriPage struct at beginning of shared memory page
        // user will have to start verizynq daemon if not there
        shmfd = shm_open (VERIZYNQ_SHMNM, O_RDWR, 0);
        if (shmfd < 0) {
            fprintf (stderr, "Z8IU32::veriopen: error opening %s: %m\n", VERIZYNQ_SHMNM);
            ABORT ();
        }

        void *ptr = mmap (NULL, sizeof *pageptr, PROT_READ | PROT_WRITE, MAP_SHARED, shmfd, 0);
        if (ptr == MAP_FAILED) ABORT ();
        pageptr = (VeriPage *) ptr;

        // make sure server process is running
        // user will have to restart it if not
        serverpid = pageptr->serverpid;
        if ((serverpid <= 0) || (kill (serverpid, 0) < 0)) {
            fprintf (stderr, "Z8IU32::veriopen: verizynq server %d dead\n", serverpid);
            ABORT ();
        }

        // set up a no-access 4K register page
        // any reads and writes not wrapped with veriread() and veriwrite() will abort
        ptr = mmap (NULL, 4096, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (ptr == MAP_FAILED) ABORT ();
        nullpage = (Z8IU32 *) ptr;
    }

    // return fd for locking
    // return a dup() in case caller closes it
    *fd_r = dup (shmfd);
    if (*fd_r < 0) ABORT ();

    return (void *) nullpage;
}

uint32_t Z8IU32::veriread ()
{
    waitforidle ();
    pageptr->index = this - nullpage;
    if (pageptr->index > 1023) ABORT ();
    return waitfordone (VERIZYNQ_READ);
}

void Z8IU32::veriwrite (uint32_t val)
{
    waitforidle ();
    pageptr->index = this - nullpage;
    if (pageptr->index > 1023) ABORT ();
    pageptr->value = val;
    waitfordone (VERIZYNQ_WRITE);
}

// simulates the ioctl (ZGIOCTL_WFI) call
// - waits for (reg[ZG_INTFLAGS] & mask) != 0
void Z8IU32::veriwfi (uint32_t mask)
{
    for (uint32_t armintmsk; ((armintmsk = pageptr->armintmsk) & mask) == 0;) {
        futexwait ((int *) &pageptr->armintmsk, armintmsk);
    }
}

// wait for the state to be IDLE
// mark the struct in use by this client
static void waitforidle ()
{
    while (true) {
        int state = pageptr->state;
        if (state != VERIZYNQ_IDLE) {
            futexwait (&pageptr->state, state);
        } else {
            if (atmcmpxchg (&pageptr->state, &state, VERIZYNQ_BUSY | mypid)) break;
        }
    }
}

// transition from BUSY to the given state
// then wait for state to be DONE
// grab the data returned therein
// finally set state to IDLE
static uint32_t waitfordone (int func)
{
    // tell verizynq daemon that we finished filling in request
    int busy = VERIZYNQ_BUSY | mypid;
    if (! atmcmpxchg (&pageptr->state, &busy, func | mypid)) ABORT ();
    if (futex (&pageptr->state, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0) ABORT ();

    // wait for verizynq daemon to complete processing the request
    int state;
    while (true) {
        state = pageptr->state;
        if (state == (VERIZYNQ_DONE | mypid)) break;
        if (state != (func | mypid)) ABORT ();
        futexwait (&pageptr->state, state);
    }

    // grab read data
    uint32_t data = pageptr->value;

    // some other client can queue a request
    if (! atmcmpxchg (&pageptr->state, &state, VERIZYNQ_IDLE)) ABORT ();
    if (futex (&pageptr->state, FUTEX_WAKE, 1000000000, NULL, NULL, 0) < 0) ABORT ();

    return data;
}

// wait for the cell to be something other than valu
// abort if server (verizynq) has exited
static void futexwait (int *cell, int valu)
{
    struct timespec when;
    memset (&when, 0, sizeof when);
    when.tv_sec = 1;
    while (true) {
        if ((pageptr->serverpid != serverpid) || (kill (serverpid, 0) < 0)) {
            fprintf (stderr, "Z8IU32::futexwait: server %d died\n", serverpid);
            ABORT ();
        }
        if (futex (cell, FUTEX_WAIT, valu, &when, NULL, 0) >= 0) break;
        int er = errno;
        if ((er == EAGAIN) || (er == EINTR)) break;
        if (er != ETIMEDOUT) ABORT ();
    }
}
