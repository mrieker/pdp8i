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
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include "z8idefs.h"
#include "z8iutil.h"

Z8IPage z8ipage;

Z8IPage::Z8IPage ()
{
    zynqpage = NULL;
    zynqptr = NULL;

    cmemat = NULL;
    pdpat  = NULL;

    mypid  = getpid ();

    if (pthread_mutex_init (&dmamtx, NULL) != 0) ABORT ();

#ifdef VERIZYNQ
    zynqptr = Z8IU32::veriopen (&zynqfd);
#else
    zynqfd = open ("/proc/zynqpdp8i", O_RDWR);
    if (zynqfd < 0) {
        fprintf (stderr, "Z8IPage::Z8IPage: error opening /proc/zynqpdp8i: %m\n");
        ABORT ();
    }

    zynqptr = mmap (NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, zynqfd, 0);
    if (zynqptr == MAP_FAILED) {
        fprintf (stderr, "Z8IPage::Z8IPage: error mmapping /proc/zynqpdp8i: %m\n");
        ABORT ();
    }
#endif

    zynqpage = (Z8IU32 *) zynqptr;
}

Z8IPage::~Z8IPage ()
{
    if (zynqptr != NULL) munmap (zynqptr, 4096);
    close (zynqfd);
    zynqpage = NULL;
    zynqptr  = NULL;
    zynqfd   = -1;
    cmemat   = NULL;
    pdpat    = NULL;
}

// find a device in the Z8I page
//  input:
//   id = NULL: all entries passed to entry() for checking
//        else: two-char string ident to check for
//   entry = NULL: return first dev that matches id
//           else: call this func to match dev
//   param = passed to entry()
//   lock = true: lock access to dev when found
//         false: don't bother locking
//  output:
//   returns pointer to dev
Z8IU32 *Z8IPage::findev (char const *id, bool (*entry) (void *param, Z8IU32 *dev), void *param, bool lockit, bool killit)
{
    for (int idx = 0; idx < 1024;) {
        Z8IU32 *dev = &zynqpage[idx];
        int len = 2 << ((*dev >> 12) & 15);
        if (idx + len > 1024) break;
        if ((id == NULL) || (((*dev >> 24) == (uint8_t) id[0]) && (((*dev >> 16) & 255) == (uint8_t) id[1]))) {
            if ((entry == NULL) || entry (param, dev)) {
                if (lockit) locksubdev (dev, len, killit);
                return dev;
            }
        }
        idx += len;
    }
    if (entry == NULL) {
        fprintf (stderr, "Z8IPage::findev: cannot find %s\n", id);
        ABORT ();
    }
    entry (param, NULL);
    return NULL;
}

// lock a sub-device
//  input:
//   start = first register of sub-device to lock
//   nwords = number of registers starting at 'start'
//   killit = true: try to kill other process if locked
//           false: abort if already locked
void Z8IPage::locksubdev (Z8IU32 *start, int nwords, bool killit)
{
    // find device that contains the start word
    int len, ofs;
    Z8IU32 *dev;
    for (int idx = 0; idx < 1024;) {
        dev = &zynqpage[idx];
        len = 2 << ((*dev >> 12) & 15);
        if (idx + len > 1024) break;
        ofs = start - dev;
        if ((ofs >= 0) && (ofs < len)) goto found;
        idx += len;
    }
    ABORT ();
found:;
    if (len - ofs < nwords) ABORT ();

    // dev = device within zynqpage
    // ofs = offset of start within dev
    // len = total number of words in device

    int kills = killit ? 3 : 0;

    while (true) {

        // try to lock the requested range
        struct flock flockit;
        memset (&flockit, 0, sizeof flockit);
        flockit.l_type   = F_WRLCK;
        flockit.l_whence = SEEK_SET;
        flockit.l_start  = (long)start - (long)zynqpage;
        flockit.l_len    = nwords * sizeof zynqpage[0];
        if (fcntl (zynqfd, F_SETLK, &flockit) >= 0) break;

        // failed, try to find out what pid has it locked
        if (((errno == EACCES) || (errno == EAGAIN)) && (fcntl (zynqfd, F_GETLK, &flockit) >= 0)) {
            if (flockit.l_type == F_UNLCK) continue;

            // print out message saying pid that has it locked
            fprintf (stderr, "Z8IPage::findev: %c%c+%d locked by pid %d\n", *dev >> 24, *dev >> 16, ofs, (int) flockit.l_pid);
            if (-- kills >= 0) {

                // try to kill it then try locking again
                fprintf (stderr, "Z8IPage::findev: killing pid %d\n", (int) flockit.l_pid);
                kill ((int) flockit.l_pid, SIGTERM);
                usleep (125000);
                continue;
            }
        } else {
            fprintf (stderr, "Z8IPage::findev: error locking %c%c: %m\n", *dev >> 24, *dev >> 16);
        }
        ABORT ();
    }
}

// do a dma cycle
//  input:
//     cm<CM_ADDR>  = 15-bit address
//     cm<CM_WRITE> = do a write access (else it's a read)
//     cm<CM_DATA>  = write data
//     cm<CM_ENAB>  = enable access
//     cm<CM_CAINC> = increment address of a 3-cycle
//     cm<CM_3CYCL> = do a 3-cycle
//  output:
//     cm<CM_DATA>  = read data
//     cm<CM_WCOVF> = wordcount overflow in 3-cycle
uint32_t Z8IPage::dmacycle (uint32_t cm)
{
    cmlock ();
    cmemat[1] = CM_BUSY | cm;
    uint32_t started = pdpat[Z_RH];
    while ((cm = cmemat[1]) & CM_BUSY) {
        uint32_t now = pdpat[Z_RH];
        uint32_t diff = now - started;
        if (diff > 100000) {    // 1mS
            fprintf (stderr, "Z8IPage::dmacycle: cmem controller is stuck %08X - %08X = %08X\n", now, started, diff);
            ABORT ();
        }
    }
    cmunlk ();
    return cm;
}

// get exclusive access (co-operative) to pdp8icmem.v device by the calling process
void Z8IPage::cmlock ()
{
    if (pthread_mutex_lock (&dmamtx) != 0) ABORT ();

    if (cmemat == NULL) cmemat = findev ("CM", NULL, NULL, false);
    if (pdpat  == NULL) pdpat  = findev ("8I", NULL, NULL, false);

    ASSERT (CM3_LOCK == 0xFFFFFFFFU);
    while (true) {
        cmemat[3] = mypid;
        int lkpid = cmemat[3];
        if (lkpid == mypid) break;
        if ((lkpid > 0) && (kill (lkpid, 0) < 0) && (errno == ESRCH)) {
            fprintf (stderr, "Z8IPage::cmlock: pid %d died, releasing lock\n", lkpid);
            cmemat[3] = lkpid;
        }
    }
    if (cmemat[1] & CM_BUSY) ABORT ();
}

// release exclusive access to pdp8icmem.v device by the calling process
void Z8IPage::cmunlk ()
{
    ASSERT (CM3_LOCK == 0xFFFFFFFFU);
    ASSERT (cmemat != NULL);
    ASSERT (! (cmemat[1] & CM_BUSY));
    ASSERT (cmemat[3] == (uint32_t) mypid);
    cmemat[3] = mypid;
    ASSERT (cmemat[3] != (uint32_t) mypid);
    if (pthread_mutex_unlock (&dmamtx) != 0) ABORT ();
}

// format shadow string
char *formatshadow (uint32_t const *shat)
{
    static char const *const msstr[] = { "---", "FET", "DEF", "EXE", "WCT", "CAD", "BRK", "IAK",
                                         "DEP", "EXM", "10 ", "11 ", "12 ", "13 ", "14 ", "15 " };

    uint32_t sh1 = shat[1];
    uint32_t sh2 = shat[2];
    uint32_t sh3 = shat[3];
    uint32_t sh4 = shat[4];
    uint32_t sh5 = shat[5];

    char *buf;
    int rc = asprintf (&buf,
        "foe=%o "
        "clr=%o "
        "err=%07X "
        "ms=%s "
        "ts=%u "
        "ir=%04o "
        "pc=%04o "
        "ma=%04o "
        "l.ac=%o.%04o "
        "sc=%02o "
        "mq=%04o",

        EXT (sh1, sh1_frzonerr),
        EXT (sh1, sh1_clearit),
        EXT (sh1, sh1_err),
        msstr[EXT(sh2,sh2_majst)],
        EXT (sh2, sh2_timestate),
        EXT (sh2, sh2_ireg),
        EXT (sh2, sh2_pctr),
        EXT (sh3, sh3_madr),
        EXT (sh4, sh4_link),
        EXT (sh4, sh4_acum),
        EXT (sh5, sh5_sctr),
        EXT (sh5, sh5_mquo));

    ASSERT (rc > 0);
    return buf;
}

// generate a random number
uint32_t randbits (int nbits)
{
    static uint64_t seed = 0x123456789ABCDEF0ULL;

    uint16_t randval = 0;

    while (-- nbits >= 0) {

        // https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
        uint64_t xnor = ~ ((seed >> 63) ^ (seed >> 62) ^ (seed >> 60) ^ (seed >> 59));
        seed = (seed << 1) | (xnor & 1);

        randval += randval + (seed & 1);
    }

    return randval;
}
