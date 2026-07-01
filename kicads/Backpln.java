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

//  Print table of backplane pins used by each circuit board

//  java Backpln > backpln.out

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.TreeMap;

public class Backpln {

    public static class Jack {
        public PCB.Network[] nets;
    }

    public static class Module {
        public PCB pcb;
        public String name;

        public Module (String nm)
                throws Exception
        {
            name = nm;
            pcb = new PCB (new BufferedReader (new FileReader (nm + "/" + nm + ".kicad_pcb")));
        }
    }

    public static void main (String[] args)
            throws Exception
    {
        Module[] mods = new Module[7];
        mods[0] = new Module ("console");
        mods[1] = new Module ("extarith");
        mods[2] = new Module ("procalu");
        mods[3] = new Module ("procreg");
        mods[4] = new Module ("procseq");
        mods[5] = new Module ("extmemory");
        mods[6] = new Module ("zturn");

        System.out.print ("      ");
        for (Module mod : mods) {
            System.out.print (String.format ("  %-14s", mod.name));
        }
        System.out.println ("");

        for (int j = 1; j <= 4; j ++) {
            System.out.println ("");
            for (int p = 1; p <= 36; p ++) {
                System.out.print (String.format ("J%d P%02d", j, p));
                for (Module mod : mods) {
                    PCB.Compon jack = mod.pcb.compons.get ("J" + j);
                    PCB.Pad pad = jack.compads[p];
                    PCB.Network net = (pad == null) ? null : pad.padnet ();
                    String netname = (net == null) ? "" : net.netnamestr;
                    char used = (net != null) && (net.refdpads.length > 1) ? '*' : ' ';
                    System.out.print (String.format ("  %c%-13s", used, netname));
                }
                System.out.println ("");
            }
        }
    }
}
