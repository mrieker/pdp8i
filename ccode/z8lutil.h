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

#ifndef _Z8LUTIL_H
#define _Z8LUTIL_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define ABORT() do { fprintf (stderr, "abort() %s:%d\n", __FILE__, __LINE__); abort (); } while (0)
#define ASSERT(cond) do { if (__builtin_constant_p (cond)) { if (!(cond)) asm volatile ("assert failure line %c0" :: "i"(__LINE__)); } else { if (!(cond)) ABORT (); } } while (0)

#ifdef VERIZYNQ
// running on a PC - access the Verilated Zynq register page via function calls
struct Z8LU32 {

    // access shared memory page
    static void *veriopen (int *fd_r);

    // reads (cast to uint32_t) get wrapped with veriread()
    operator uint32_t ()
    {
        return veriread ();
    }

    // writes get wrapped with veriwrite()
    Z8LU32& operator= (uint32_t rhs)
    {
        veriwrite (rhs);
        return *this;
    }

    // modifies
    Z8LU32& operator&= (uint32_t rhs)
    {
        veriwrite (veriread () & rhs);
        return *this;
    }

    Z8LU32& operator|= (uint32_t rhs)
    {
        veriwrite (veriread () | rhs);
        return *this;
    }

private:
    uint32_t dummy; // so sizeof (Z8LU32) == 4

    void veriwrite (uint32_t val);
    uint32_t veriread ();
};
#else
// running on a Zynq - access register page directly
typedef uint32_t volatile Z8LU32;
#endif

struct Z8LPage {
    Z8LPage ();
    virtual ~Z8LPage ();
    Z8LU32 *findev (char const *id, bool (*entry) (void *param, Z8LU32 *dev), void *param, bool lockit, bool killit = false);
    void locksubdev (Z8LU32 *start, int nwords, bool killit);

    uint32_t dmacycle (uint32_t cm, uint32_t cm2);
    void dmaflush ();
    void cmlock ();
    void cmunlk ();

private:
    int zynqfd;
    Z8LU32 *cmemat;
    Z8LU32 *xmemat;
    Z8LU32 *zynqpage;
    void *zynqptr;

    static uint32_t mypid;
};

char *formatshadow (uint32_t *shat);
uint32_t randbits (int nbits);

#endif
