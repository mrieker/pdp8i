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

// continually print out all tester module pins

// cc -Wall -O2 -o i2ctest i2ctest.cc i2cmaster.cc
// ./i2ctest

#include <stdint.h>
#include <stdio.h>

#include "i2cmaster.h"

int main (int argc, char **argv)
{
    setlinebuf (stdout);
    while (true) {
        for (int bus = 1; bus <= 2; bus ++) {
            for (uint64_t addr = 0x20; addr < 0x28; addr ++) {
                uint64_t readdata = 0;
                int rc = i2cmaster (bus,
                    (I2CWR << 62) | (addr << 55) | (I2CWW << 54) |
                    (I2CWR << 52) | (0x12ULL << 44) |
                    (I2CRS << 42) |
                    (I2CWR << 40) | (addr << 33) | (I2CRR << 32) |
                    (I2CRD << 30) | (I2CRD << 28),
                    &readdata
                );
                if (rc < 0) printf (" %4d", rc);
                else printf (" %04X", (unsigned)readdata);
            }
        }
        printf ("\n");
    }
    return 0;
}
