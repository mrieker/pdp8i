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

// generate string for current shadow error(s)

#include "strprintf.h"
#include "z8idefs.h"
#include "z8iutil.h"

void shaderr (std::string *str, char const *sep)
{
    char const *sss = "";

    Z8IU32 *pdpat  = z8ipage.findev ("8I", NULL, NULL, false);
    Z8IU32 *shat   = z8ipage.findev ("SH", NULL, NULL, false);

    uint32_t rc  = pdpat[Z_RE];
    uint32_t re  = pdpat[Z_RE];
    uint32_t rf  = pdpat[Z_RF];

    uint32_t sh1 = shat[1];
    uint32_t sh2 = shat[2];
    uint32_t sh3 = shat[3];
    uint32_t sh4 = shat[4];
    uint32_t sh5 = shat[5];
    uint32_t sh6 = shat[6];

    uint32_t iCAINC    = EXT (rc, c_dev_iCAINC);
    uint32_t iDMAFLD   = EXT (rc, c_dev_iDMAFLD);
    uint32_t oACUM     = EXT (rf, f_oACUM);
    uint32_t oIOP      = EXT (rf, f_oIOP);
    uint32_t oLINK     = EXT (rf, f_oLINK);
    uint32_t oMADR     = EXT (re, e_oMADR);
    uint32_t oMAJST    = EXT (rf, f_oMAJST);
    uint32_t oMBUF     = EXT (re, e_oMBUF);
    uint32_t oMEAD     = EXT (re, e_oMEAD);
    uint32_t oTS1      = EXT (rf, f_oTS1);
    uint32_t oTS2      = EXT (rf, f_oTS2);
    uint32_t oTS3      = EXT (rf, f_oTS3);
    uint32_t oTS4      = EXT (rf, f_oTS4);

    uint32_t acum      = EXT (sh4, sh4_acum);
    uint32_t dfld      = EXT (sh4, sh4_dfld);
    uint32_t err1      = EXT (sh1, sh1_err1);
    uint32_t err2      = EXT (sh6, sh6_err2);
    uint32_t extarstep = EXT (sh6, sh6_extarstep);
    uint32_t ifld      = EXT (sh5, sh5_ifld);
    uint32_t intenabd  = EXT (sh3, sh3_intenabd);
    uint32_t intinhuj  = EXT (sh3, sh3_intinhuj);
    uint32_t ireg      = EXT (sh2, sh2_ireg);
    uint32_t lastts1   = EXT (sh3, sh3_lastts1);
    uint32_t lastts2   = EXT (sh3, sh3_lastts2);
    uint32_t lastts3   = EXT (sh3, sh3_lastts3);
    uint32_t lastts4   = EXT (sh3, sh3_lastts4);
    uint32_t link      = EXT (sh5, sh5_link);
    uint32_t madr      = EXT (sh3, sh3_madr);
    uint32_t majst     = EXT (sh2, sh2_majst);
    uint32_t mbrd      = EXT (sh3, sh3_mbrd);
    uint32_t pctr      = EXT (sh2, sh2_pctr);
    uint32_t sctr      = EXT (sh5, sh5_sctr);
    uint32_t tp1dat    = EXT (sh6, sh6_tp1dat);
    uint32_t tp1fld    = EXT (sh6, sh6_tp1fld);

    if ((err1 >>  0) & 1) {
        strprintf (str, "%s1.00 ts1/ts3 overlap oTS1=%o lastts1=%o oTS3=%o lastts3=%o", sss, oTS1, lastts1, oTS3, lastts3);
        sss = sep;
    }
    if ((err1 >>  1) & 1) {
        strprintf (str, "%s1.01 ts2/ts4 overlap oTS2=%o lastts2=%o oTS4=%o lastts4=%o", sss, oTS2, lastts2, oTS4, lastts4);
        sss = sep;
    }
    if ((err1 >>  2) & 1) {
        strprintf (str, "%s1.02 ts1/ts3,4 overlap oTS3=%o oTS4=%o", sss, oTS3, oTS4);
        sss = sep;
    }
    if ((err1 >>  3) & 1) {
        strprintf (str, "%s1.03 tp1 majst mismatch majst=%X oMAJST=%X", sss, majst, oMAJST);
        sss = sep;
    }
    if ((err1 >>  4) & 1) {
        strprintf (str, "%s1.04 tp1 madr mismatch majst=%X madr=%04o oMADR=%04o", sss, majst, madr, oMADR);
        sss = sep;
    }
    if ((err1 >>  5) & 1) {
        strprintf (str, "%s1.05 pctr/madr mismatch majst=%X pctr=%04o oMADR=%04o", sss, majst, pctr, oMADR);
        sss = sep;
    }
    if ((err1 >>  6) & 1) {
        strprintf (str, "%s1.06 ts2/ts1,4 overlap oTS1=%o oTS4=%o", sss, oTS1, oTS4);
        sss = sep;
    }
    if ((err1 >>  7) & 1) {
        strprintf (str, "%s1.07 end of ts2 iop mismatch majst=%X ireg=%04o oIOP=%o", sss, majst, ireg, oIOP);
        sss = sep;
    }
    if ((err1 >>  8) & 1) {
        strprintf (str, "%s1.08 ts3/ts1,2 overlap oTS1=%o oTS2=%o", sss, oTS1, oTS2);
        sss = sep;
    }
    if ((err1 >>  9) & 1) {
        strprintf (str, "%s1.09 ts3 fetch mbuf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 10) & 1) {
        strprintf (str, "%s1.10 ts3 defer mbuf mismatch oMBUF=%04o mbrd=%04o madr=%04o", sss, oMBUF, mbrd, madr);
        sss = sep;
    }
    if ((err1 >> 11) & 1) {
        strprintf (str, "%s1.11 ts3 isz mbuf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 12) & 1) {
        strprintf (str, "%s1.12 ts3 dca acum/mbuf mismatch oMBUF=%04o acum=%04o", sss, oMBUF, acum);
        sss = sep;
    }
    if ((err1 >> 13) & 1) {
        strprintf (str, "%s1.13 ts3 jms old pctr/mbuf mismatch oMBUF=%04o pctr=%04o", sss, oMBUF, pctr);
        sss = sep;
    }
    if ((err1 >> 14) & 1) {
        strprintf (str, "%s1.14 ts3 mbuf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 15) & 1) {
        strprintf (str, "%s1.15 ts3 wrdct mbuf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 16) & 1) {
        strprintf (str, "%s1.16 ts3 curad mbuf mismatch oMBUF=%04o mbrd=%04o iCAINC=%o", sss, oMBUF, mbrd, iCAINC);
        sss = sep;
    }
    if ((err1 >> 17) & 1) {
        strprintf (str, "%s1.17 ts3 intak mbuf/pctr mismatch oMBUF=%04o pctr=%04o", sss, oMBUF, pctr);
        sss = sep;
    }
    if ((err1 >> 18) & 1) {
        strprintf (str, "%s1.18 ts3 exam mbuf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 19) & 1) {
        strprintf (str, "%s1.19 ts4 overlap ts2,3 oTS2=%o oTS3=%o", sss, oTS2, oTS3);
        sss = sep;
    }
    if ((err1 >> 20) & 1) {
        strprintf (str, "%s1.20 ts4 link.acum mismatch ireg=%04o majst=%X oLINK.ACUM=%o.%04o link.acum=%o.%04o", sss, ireg, majst, oLINK, oACUM, link, acum);
        sss = sep;
    }
    if ((err1 >> 21) & 1) {
        strprintf (str, "%s1.21 end ts4 madr/pctr mismatch oMEAD,oMADR=%o%04o ifld,pctr=%o%04o", sss, oMEAD, oMADR, ifld, pctr);
        sss = sep;
    }
    if ((err1 >> 22) & 1) {
        strprintf (str, "%s1.22 ts4 extarith still running extarstep=%o sctr=%02o", sss, extarstep, sctr);
        sss = sep;
    }
    if ((err1 >> 23) & 1) {
        strprintf (str, "%s1.23 end ts4 hlt did not halt ireg=%04o oTS1=%o", sss, ireg, oTS1);
        sss = sep;
    }
    if ((err1 >> 24) & 1) {
        strprintf (str, "%s1.24 end ts4 did not halt at end of depos,exam majst=%X", sss, majst);
        sss = sep;
    }
    if ((err1 >> 25) & 1) {
        strprintf (str, "%s1.25 ts4 extarith still running extarstep=%o sctr=%02o", sss, extarstep, sctr);
        sss = sep;
    }
    if ((err1 >> 26) & 1) {
        strprintf (str, "%s1.26 ts3 curad mbhf mismatch oMBUF=%04o mbrd=%04o", sss, oMBUF, mbrd);
        sss = sep;
    }
    if ((err1 >> 27) & 1) {
        strprintf (str, "%s1.27 tp1 intak with ints disabled intenabd=%o intinhuj=%o", sss, intenabd, intinhuj);
        sss = sep;
    }
    if ((err1 >> 28) & 1) {
        strprintf (str, "%s1.28 ts3 mead.madr mismatch majst=%X madr sb %o.%04o but is %o.%04o", sss, majst, tp1fld, madr, oMEAD, oMADR);
        sss = sep;
    }
    if ((err1 >> 29) & 1) {
        strprintf (str, "%s1.29 beg ts2 mbuf mismatch majst=%X oMADR=%o.%04o oMBUF=%04o iINBUS=%04o", sss, majst, oMEAD, oMADR, oMBUF, tp1dat);
        sss = sep;
    }
    if ((err2 >>  0) & 1) {
        strprintf (str, "%s2.00 tp1 ifld/mead mismatch majst=%X ifld=%o oMEAD=%o", sss, majst, ifld, oMEAD);
        sss = sep;
    }
    if ((err2 >>  1) & 1) {
        strprintf (str, "%s2.01 tp1 dfld/mead mismatch majst=%X dfld=%o oMEAD=%o", sss, majst, dfld, oMEAD);
        sss = sep;
    }
    if ((err2 >>  2) & 1) {
        strprintf (str, "%s2.02 tp1 ifld/mead mismatch majst=%X ifld=%o oMEAD=%o", sss, majst, ifld, oMEAD);
        sss = sep;
    }
    if ((err2 >>  3) & 1) {
        strprintf (str, "%s2.03 tp1 mead should be 0 majst=%X oMEAD=%o", sss, majst, oMEAD);
        sss = sep;
    }
    if ((err2 >>  4) & 1) {
        strprintf (str, "%s2.04 tp1 dmafld/mead mismatch iDMAFLD=%o oMEAD=%o", sss, iDMAFLD, oMEAD);
        sss = sep;
    }
}
