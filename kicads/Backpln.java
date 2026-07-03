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

// Print table of backplane pin network names used by each circuit board
// Then check that backplane.kicad_pcb connector pins have matching network names

//  java Backpln > backpln.out

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.TreeMap;

public class Backpln {

    // each module assumed to have 36-pin backplane connectors named J1 J2 J3 J4
    // ...with pins numbered P1..P36
    public static class Module {
        public boolean[] paduseds;  // pin is used by module
        public int bpj1;            // which backplane connector mates with J1
        public PCB pcb;             // module kicad_pcb file
        public String name;         // module name
        public String[] padnets;    // network name for each pin

        public Module (String nm, int bpj1)
                throws Exception
        {
            this.bpj1 = bpj1;
            name = nm;
            pcb = new PCB (new BufferedReader (new FileReader (nm + "/" + nm + ".kicad_pcb")));

            paduseds = new boolean[144];
            padnets  = new String[144];
            for (int j = 1; j <= 4; j ++) {
                PCB.Compon jack = pcb.compons.get ("J" + j);
                for (int p = 1; p <= 36; p ++) {
                    PCB.Pad pad = jack.compads[p];
                    PCB.Network net = (pad == null) ? null : pad.padnet ();
                    int i = (j - 1) * 36 + (p - 1);
                    padnets[i]  = (net == null) ? "" : net.netnamestr;
                    paduseds[i] = (net != null) && (net.refdpads.length > 1);
                }
            }
        }

        // see if the pin is used by the module
        public boolean padused (int j, int p)
        {
            int i = (j - 1) * 36 + (p - 1);
            return paduseds[i];
        }

        // get network the module uses for the oin
        public String padnet (int j, int p)
        {
            int i = (j - 1) * 36 + (p - 1);
            return padnets[i];
        }
    }

    public static void main (String[] args)
            throws Exception
    {
        Module[] mods = new Module[8];
        mods[0] = new Module ("console",    1);
        mods[1] = new Module ("extardata",  5);
        mods[2] = new Module ("extarctrl",  9);
        mods[3] = new Module ("procalu",   13);
        mods[4] = new Module ("procreg",   17);
        mods[5] = new Module ("procseq",   21);
        mods[6] = new Module ("extmemory", 25);
        mods[7] = new Module ("zturn",     29);

        // print table of pins that module connects to backplane
        for (int j = 1; j <= 4; j ++) {
            System.out.println ("");
            System.out.print ("       ");
            for (Module mod : mods) {
                System.out.print (String.format ("  %-18s", mod.name));
            }
            System.out.println ("");
            for (int p = 1; p <= 36; p ++) {
                System.out.print (String.format ("J%d P%02d", j, p));
                for (Module mod : mods) {
                    String net = mod.padnet (j, p);
                    char used = mod.padused (j, p) ? '*' : ' ';
                    System.out.print (String.format ("  %c%-17s", used, net));
                }
                System.out.println ("");
            }
        }

        // make sure those pins all match backplane.kicad_pcb pins
        PCB bplpcb = new PCB (new BufferedReader (new FileReader ("backplane/backplane.kicad_pcb")));
        boolean error = false;
        for (Module mod : mods) {
            for (int modjn = 1; modjn <= 4; modjn ++) {
                int bpjn = mod.bpj1 + modjn - 1;
                PCB.Compon bpjc = bplpcb.compons.get ("J" + bpjn);
                for (int p = 1; p <= 36; p ++) {
                    String modpadnetname = mod.padnet (modjn, p);
                    PCB.Pad bplpad = bpjc.compads[p];
                    PCB.Network bplnet = (bplpad == null) ? null : bplpad.padnet ();
                    String bplpadnetname = (bplnet == null) ? "" : bplnet.netnamestr;
                    if (! bplpadnetname.equals (modpadnetname)) {
                        System.err.println ("backplane J" + bpjn + " P" + p + " " + bplpadnetname + " != " + mod.name + " J" + modjn + " P" + p + " " + modpadnetname);
                        error = true;
                    }
                }
            }
        }
        if (error) System.exit (1);
    }
}
