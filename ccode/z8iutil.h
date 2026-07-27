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

#ifndef _Z8IUTIL_H
#define _Z8IUTIL_H

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define ABORT() do { fprintf (stderr, "abort() %s:%d\n", __FILE__, __LINE__); abort (); } while (0)
#define ASSERT(cond) do { if (__builtin_constant_p (cond)) { if (!(cond)) asm volatile ("assert failure line %c0" :: "i"(__LINE__)); } else { if (!(cond)) ABORT (); } } while (0)

#ifdef VERIZYNQ
// running on a PC - access the Verilated Zynq register page via function calls
struct Z8IU32 {

    // access shared memory page
    static void *veriopen (int *fd_r);

    // reads (cast to uint32_t) get wrapped with veriread()
    operator uint32_t ()
    {
        return veriread ();
    }

    // writes get wrapped with veriwrite()
    Z8IU32& operator= (uint32_t rhs)
    {
        veriwrite (rhs);
        return *this;
    }

    // modifies
    Z8IU32& operator&= (uint32_t rhs)
    {
        veriwrite (veriread () & rhs);
        return *this;
    }

    Z8IU32& operator|= (uint32_t rhs)
    {
        veriwrite (veriread () | rhs);
        return *this;
    }

    // wait for interrupt from zynq
    static void veriwfi (uint32_t mask);

private:
    uint32_t dummy; // so sizeof (Z8IU32) == 4

    void veriwrite (uint32_t val);
    uint32_t veriread ();
};
#else
// running on a Zynq - access register page directly
typedef uint32_t volatile Z8IU32;
#endif

struct Z8IPage {
    Z8IPage ();
    virtual ~Z8IPage ();
    Z8IU32 *findev (char const *id, bool (*entry) (void *param, Z8IU32 *dev), void *param, bool lockit, bool killit = false);
    void locksubdev (Z8IU32 *start, int nwords, bool killit);

    uint32_t dmacycle (uint32_t cm);
    void cmlock ();
    void cmunlk ();

    void waitint (uint32_t mask);

private:
    int mypid;
    int zynqfd;
    pthread_mutex_t dmamtx;
    void *zynqptr;
    Z8IU32 *cmemat;
    Z8IU32 *pdpat;
    Z8IU32 *zynqpage;
};

extern Z8IPage z8ipage;

uint32_t randbits (int nbits);

#endif
