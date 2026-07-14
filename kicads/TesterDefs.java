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

// Parse tester.kicad_pcb file
// Print out testerdefs.h

import java.io.BufferedReader;
import java.io.InputStreamReader;

public class TesterDefs {
    public static void main (String[] args)
            throws Exception
    {
        PCB pcb = new PCB (new BufferedReader (new InputStreamReader (System.in)));

        String[] mpnames = new String[256];
        String[] cpnames = new String[256];

        System.out.println ("#ifndef _TESTERDEFS_H");
        System.out.println ("#define _TESTERDEFS_H");

        // output defines for mcp23017 pins
        for (int bus = 1; bus <= 2; bus ++) {                   // 1=U10..14; 2=U21..25
            for (int chip = bus - 1; chip < bus + 4; chip ++) {
                System.out.println ("");
                PCB.Compon mcp = pcb.compons.get ("U" + bus + chip);
                for (int port = 1; port <= 2; port ++) {        // 1='A'; 2='B'
                    for (int bit = 0; bit < 8; bit ++) {
                        int p = (2 - port) * 20 + bit + 1;      // P21=A0; P1=B0
                        PCB.Pad pin = mcp.compads[p];
                        PCB.Network net = pin.padnet ();
                        String nn = net.netname;
                        if (! nn.startsWith ("unconnected")) {
                            if (nn.startsWith ("Net__")) nn = nn.substring (5);
                            int mp = (2 - bus) * 128 + chip * 16 + (port - 1) * 8 + bit;
                            System.out.println (String.format ("#define mp_%-14s %3d  // U%d%d %c%d P%d",
                                nn, mp, bus, chip, 'A' + port - 1, bit, p));
                            mpnames[mp] = nn;
                        }
                    }
                }
            }
        } 

        // output defines for connector pins
        for (int j = 1; j <= 4; j ++) {
            System.out.println ("");
            PCB.Compon jack = pcb.compons.get ("J" + j);
            for (int p = 2; p <= 35; p ++) {
                PCB.Pad pin = jack.compads[p];
                PCB.Network net = pin.padnet ();
                int cp = (j - 1) * 64 + p;
                System.out.println (String.format ("#define cp_%-14s %3d   // J%d P%d", net.netname, cp, j, p));
                cpnames[cp] = net.netname;
            }
        }

        System.out.println ("");
        System.out.println ("#endif");

        System.out.println ("");
        System.out.println ("#ifdef _TESTLIB_CC");

        // output names for mcp23017 pins
        System.out.println ("");
        System.out.println ("char const *const mpnames[256] = {");
        for (int mp = 0; mp < 256; mp ++) {
            String piname = mpnames[mp];
            if (piname != null) {
                System.out.print ("\"" + piname + "\",");
            } else {
                System.out.print ("NULL,");
            }
            if (mp % 16 == 15) {
                int u = ((mp >> 7) + 1) * 10  + ((mp >> 4) & 7);
                System.out.println ("  // U" + u);
            }
        }
        System.out.println ("};");

        // output names for connector pins
        System.out.println ("");
        System.out.println ("int const mptocp[256] = {");
        for (int mp = 0; mp < 256; mp ++) {
            String piname = mpnames[mp];
            int cp = 0;
            if (piname != null) {
                for (int i = 0; i < 256; i ++) {
                    if (piname.equals (cpnames[i])) {
                        cp = i;
                    }
                }
            }
            System.out.print (String.format ("%4d,", cp));
            if (mp % 16 == 15) {
                int u = ((mp >> 7) + 1) * 10  + ((mp >> 4) & 7);
                System.out.println ("  // U" + u);
            }
        }
        System.out.println ("};");

        System.out.println ("");
        System.out.println ("char const *const cpnames[256] = {");
        for (int cp = 0; cp < 256; cp ++) {
            String piname = cpnames[cp];
            if (piname != null) {
                System.out.print ("\"" + piname + "\",");
            } else {
                System.out.print ("NULL,");
            }
            if (cp % 16 == 15) {
                System.out.println ("");
            }
        }
        System.out.println ("};");

        System.out.println ("");
        System.out.println ("int const cptomp[256] = {");
        for (int cp = 0; cp < 256; cp ++) {
            String piname = cpnames[cp];
            int mp = 0;
            if (piname != null) {
                for (int i = 0; i < 256; i ++) {
                    if (piname.equals (mpnames[i])) {
                        mp = i;
                    }
                }
            }
            System.out.print (String.format ("%4d,", mp));
            if (cp % 16 == 15) System.out.println ("");
        }
        System.out.println ("};");

        System.out.println ("");
        System.out.println ("#endif");
    }
}
