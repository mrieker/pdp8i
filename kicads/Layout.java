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
import java.util.LinkedList;
import java.util.TreeMap;

public class Layout {
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

    /***
        for (PCB.Compon compon : compons.values ()) {
            System.out.println ("comp " + compon.refer + " (" + compon.atxin + "," + compon.atyin + ")");
            for (PCB.Pad pad : compon.pads) {
                if (pad == null) continue;
                System.out.println ("   p" + pad.padidx + " (" + pad.atxin + "," + pad.atyin + ") " + (pad.padnet == null ? "" : pad.padnet.netname));
            }
        }
    ***/

        double totallen = 0;
        for (PCB.Network network : netsbyname.values ()) {
            double ntl = NetTotalLen (network);
            System.out.println ("net " + network.netname + " totalen=" + inchstr (ntl));
            totallen += ntl;
        }
        System.out.println ("totallen=" + inchstr (totallen));
    }

    // compute the total trace length (inches) to wire a network to all connected pins
    public static double NetTotalLen (PCB.Network network)
    {
        double totallen = 0;
        for (int j = 0; j < network.refdpads.length; j ++) {
            PCB.Pad firstpad = network.refdpads[j];
            double firstpadatxin = firstpad.atxin + firstpad.compon.atxin;
            double firstpadatyin = firstpad.atyin + firstpad.compon.atyin;
            double closestdist = Double.NaN;
            for (int i = j; ++ i < network.refdpads.length;) {
                PCB.Pad pad = network.refdpads[i];
                double padatxin = pad.atxin + pad.compon.atxin;
                double padatyin = pad.atyin + pad.compon.atyin;
                double dist = Math.hypot (padatxin - firstpadatxin, padatyin - firstpadatyin);
                if (Double.isNaN (closestdist) || (closestdist > dist)) {
                    closestdist = dist;
                }
            }
            if (! Double.isNaN (closestdist)) {
                totallen += closestdist;
            }
        }
        return totallen;
    }

    public static String inchstr (double inch)
    {
        int hundths = (int) Math.round (inch * 100.0);
        return Integer.toString (hundths / 100) + "." + Integer.toString (hundths % 100 + 100).substring (1);
    }
}
