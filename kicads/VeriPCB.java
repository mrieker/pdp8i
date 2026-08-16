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

// Parse a KiCad PCB file
// Print out Verilog equivalent

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.TreeMap;

public class VeriPCB {
    public static boolean error;

    public static TreeMap<String,PCB.Network>  netsbyname;
    public static TreeMap<Integer,PCB.Network> netsbynum;
    public static TreeMap<String,PCB.Compon>   compons;

    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the pcb file
        PCB pcb = new PCB (new BufferedReader (new InputStreamReader (System.in)));
        netsbyname = pcb.netsbyname;
        netsbynum  = pcb.netsbynum;
        compons    = pcb.compons;

        // print networks
        // - if referenced by a connector, it is an input/output pin for the module
        // - if not refd by a connector, it is a wire
        System.out.println ("module " + modname + " (input zclock, zreset");
        char sep = ',';
        sep = printconpins (sep, "input");
        sep = printconpins (sep, "inout");
        sep = printconpins (sep, "output");
        System.out.println (");");

        System.out.println ("");
        for (PCB.Network network : netsbyname.values ()) {
            if (! network.netport && ! network.netname.equals ("")) {
                System.out.println (String.format ("    wire %s;", network.netname));
                if ((network.netrefs == 0) && ! network.netname.startsWith ("unconnected__")) {
                    System.err.println ("nothing drives " + network.netname);
                    error = true;
                }
            }
        }

        // print non-connector components as module instantiations
        for (String refer : compons.keySet ()) {
            PCB.Compon compon = compons.get (refer);
            if (! compon.isconnector ()) {
                printcompon (compon);
            }
        }

        // output assign statements for wired-and tri-state networks
        boolean first = true;
        for (PCB.Network network : netsbyname.values ()) {
            if (! network.trinetnames.isEmpty ()) {
                if (first) System.out.println ("");
                // trinetnames contains all internally generated signals
                // netname = signal that contains all signals (internal and external) anded together
                // if it is on a connector, we assume external circuitry will and everything together,
                //   passing that big anded signal to our input pin named simply netname,
                //   and the target of the and is netname_o (going to output pin)
                // if not a connector, the target of the and is simply netname
                System.out.print ("    assign " + network.netname);
                if (network.netport) System.out.print ("_o");
                System.out.print (" = ");
                first = true;
                for (String tnn : network.trinetnames) {
                    if (! first) System.out.print (" & ");
                    System.out.print (tnn);
                    first = false;
                }
                System.out.println (";");
                first = false;
            }
        }
        if (! first) System.out.println ("");

        System.out.println ("endmodule");

        if (error) System.exit (1);
    }

    // print connector pin network names for a module statement
    // skip pins not connected to anything even if it has a network name
    //  input:
    //   sep = separator character
    //   keywrd = "input", "inout" or "output" : print network names for that type
    //   netsbyname = all networks indexed by name
    //  output:
    //   prints matching network names
    //   returns new separator char
    public static char printconpins (char sep, String keywrd)
    {
        for (PCB.Network network : netsbyname.values ()) {
            if (network.netport && ! network.netname.startsWith ("unconnected") && (network.refdpads.length > 1)) {
                String porttype = "input";
                if (network.netrefs > 0) porttype = "inout";
                if (network.netrefs < 0) porttype = "output";
                if (porttype.equals (keywrd)) {
                    if (porttype.equals ("inout")) {
                        System.out.println ("    " + sep + " input " + network.netname);  // everything anded together
                        sep = ',';
                        System.out.println ("    " + sep + " output " + network.netname + "_o");  // all internals anded
                        sep = ',';
                    } else {
                        System.out.println ("    " + sep + " " + porttype + " " + network.netname);
                        sep = ',';
                    }
                }
            }
        }
        return sep;
    }

    public static void printcompon (PCB.Compon compon)
    {
        System.out.println ("");

        // print wire statements for each tri-state pin
        //  wire <netname>_<uname>p<pinnum>;
        for (PCB.Pad pad : compon.compads) {
            if ((pad != null) && (pad.pintype == PCB.PinType.TRISTATE)) {
                PCB.Network network = pad.padnet ();
                String tnn = network.netname + "_" + compon.refer + "p" + pad.padidx;
                network.trinetnames.add (tnn);
                System.out.println ("    wire " + tnn + ";");
            }
        }

        // output module instantiation
        System.out.println ("    X" + compon.value + " " + compon.refer + " (");
        System.out.println ("        .zclock(zclock),");
        System.out.println ("        .zreset(zreset)");
        for (PCB.Pad pad : compon.compads) {
            if (pad != null) {
                int idx = pad.padidx;
                PCB.Network network = pad.padnet ();
                if (network != null) {
                    String netname = network.netname;
                    if (pad.pintype == PCB.PinType.TRISTATE) {
                        String tnn = netname + "_" + compon.refer + "p" + idx;
                        System.out.println (String.format ("        , .p%di(%s) // TRISTATE", idx, netname));
                        System.out.println (String.format ("        , .p%do(%s) // TRISTATE", idx, tnn));
                    } else {
                        System.out.println (String.format ("        , .p%d(%s) // %s", idx, netname, pad.pintype.toString ()));
                    }
                } else {
                        System.out.println (String.format ("        , .p%d() // %s", idx, pad.pintype.toString ()));
                }
            }
        }
        System.out.println ("    );");
    }
}
