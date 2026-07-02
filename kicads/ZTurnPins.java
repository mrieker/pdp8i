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

// Create signals.xdc file from zturn.kicad_pcb

// java ZTurnPins > ../zynq/signals.xdc

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.TreeMap;

public class ZTurnPins {

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
        // read pcb file
        PCB ztpcb = new PCB (new BufferedReader (new FileReader ("zturn/zturn.kicad_pcb")));

        // find J11 and J12
        PCB.Compon j11 = ztpcb.compons.get ("J11");
        PCB.Compon j12 = ztpcb.compons.get ("J12");
        if ((j11 == null) || (j11 == null)) throw new Exception ("missing J11 or J12");
        PCB.Compon[] jcompons = { j11, j12 };

        // read zturnpins.csv
        String[] j11pins = new String[80];
        String[] j12pins = new String[80];
        BufferedReader ztpcsv = new BufferedReader (new FileReader ("../zturnpins.csv"));
        for (String csvline; (csvline = ztpcsv.readLine ()) != null;) {
            String[] parts = csvline.split (",");
            if (parts.length >= 3) {
                String[] jarray = null;
                if (parts[0].startsWith ("J11-")) jarray = j11pins;
                if (parts[0].startsWith ("J12-")) jarray = j12pins;
                if (jarray != null) {
                    int pin = Integer.parseInt (parts[0].substring (4));
                    jarray[pin-1] = parts[2];
                }
            }
        }
        ztpcsv.close ();
        String[][] jpinss = { j11pins, j12pins };

        // set_property PACKAGE_PIN G15 [get_ports {hdw_iINBUS_0[3]}]  ; set_property IOSTANDARD LVCMOS33 [get_ports {hdw_iINBUS_0[3]}]

        // correlate pins and networks
        for (int i = 0; i < 2; i ++) {
            PCB.Compon jcomp = jcompons[i];
            String[] jpins = jpinss[i];
            for (PCB.Pad pad : jcomp.compads) {
                PCB.Network padnet = (pad == null) ? null : pad.padnet ();
                if (padnet != null) {
                    String netname = padnet.netname;
                    if (netname.equals ("GND")) continue;
                    if (netname.equals ("V5ZYNQ")) continue;
                    if (netname.equals ("_3V3")) continue;
                    if (netname.startsWith ("unconnected")) continue;

                    String zynqpad = jpins[pad.padidx-1];
                    int j = netname.lastIndexOf ('_');
                    if (j > 0) {
                        try {
                            int n = Integer.parseInt (netname.substring (j + 1));
                            netname = "{" + netname.substring (0, j) + "[" + n + "]}";
                        } catch (NumberFormatException nfe) {
                        }
                    }
                    System.out.println (
                        "set_property PACKAGE_PIN " + zynqpad +
                        " [get_ports " + netname +
                        "] ; set_property IOSTANDARD LVCMOS33 [get_ports " + netname + "]");
                }
            }
        }
    }
}
