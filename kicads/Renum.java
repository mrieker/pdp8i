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

// Renumber ICs from column and row

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.TreeMap;

public class Renum {
    public static TreeMap<String,PCB.Network>  netsbyname;
    public static TreeMap<Integer,PCB.Network> netsbynum;
    public static PCB.Compon[] iccompons;

    public static SCM.ArrValue schemtop;
    public static SCM.ArrValue[] schemsyms;

    public static int numcols;
    public static int numrows;
    public static int colwid20thin;
    public static int rowhit20thin;

    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the pcb file
        PCB pcb = new PCB (new BufferedReader (new FileReader (modname + ".kicad_pcb")));
        netsbyname = pcb.netsbyname;
        netsbynum  = pcb.netsbynum;

        // get list of all chips on the board
        int niccompons = 0;
        for (PCB.Compon compon : pcb.compons.values ()) {
            if (compon.refer.startsWith ("U")) {
                niccompons ++;
            }
        }
        iccompons = new PCB.Compon[niccompons];
        niccompons = 0;
        for (PCB.Compon compon : pcb.compons.values ()) {
            if (compon.refer.startsWith ("U")) {
                iccompons[niccompons++] = compon;
            }
        }

        // get cell row and column sizes and quantities
        HashSet<Integer> col20thins = new HashSet<> ();
        HashSet<Integer> row20thins = new HashSet<> ();
        int minatx20thin = 1000000000;
        int maxatx20thin = -999999999;
        int minaty20thin = 1000000000;
        int maxaty20thin = -999999999;
        for (PCB.Compon compon : iccompons) {
            int atx20thin = (int) Math.round (compon.atxin () * 20);
            int aty20thin = (int) Math.round (compon.atyin () * 20);
            col20thins.add (atx20thin);
            row20thins.add (aty20thin);
            if (minatx20thin > atx20thin) minatx20thin = atx20thin;
            if (maxatx20thin < atx20thin) maxatx20thin = atx20thin;
            if (minaty20thin > aty20thin) minaty20thin = aty20thin;
            if (maxaty20thin < aty20thin) maxaty20thin = aty20thin;
        }
        numcols = col20thins.size ();
        numrows = row20thins.size ();
        colwid20thin = (maxatx20thin - minatx20thin) / (numcols - 1);
        rowhit20thin = (maxaty20thin - minaty20thin) / (numrows - 1);

        System.err.println ("numcols=" + numcols);
        System.err.println ("numrows=" + numrows);
        System.err.println ("minatx20thin=" + minatx20thin);
        System.err.println ("minaty20thin=" + minaty20thin);
        System.err.println ("colwid20thin=" + colwid20thin);
        System.err.println ("rowhit20thin=" + rowhit20thin);

        for (int strlen = 4; strlen > 0; -- strlen) {
            for (PCB.Compon compon : iccompons) {
                if (compon.refer.length () == strlen) {
                    int atx20thin = (int) Math.round (compon.atxin () * 20);
                    int aty20thin = (int) Math.round (compon.atyin () * 20);

                    int origcol = (atx20thin - minatx20thin) / colwid20thin + 1;
                    int origrow = (aty20thin - minaty20thin) / rowhit20thin + 1;

                    int rotdrow = origcol;
                    int rotdcol = numrows + 1 - origrow;

                    System.out.println ("s/\"" + compon.refer + "\"/\"E" + Integer.toString (rotdrow * 10 + rotdcol) + "\"/w");
                }
            }
        }

        for (int strlen = 4; strlen > 0; -- strlen) {
            for (PCB.Compon compon : pcb.compons.values ()) {
                if (compon.refer.startsWith ("C") && (compon.refer.length () == strlen)) {
                    int atx20thin = (int) Math.round (compon.atxin () * 20) + 3;
                    int aty20thin = (int) Math.round (compon.atyin () * 20);

                    int origcol = (atx20thin - minatx20thin) / colwid20thin + 1;
                    int origrow = (aty20thin - minaty20thin) / rowhit20thin + 1;

                    int rotdrow = origcol;
                    int rotdcol = numrows + 1 - origrow;

                    System.out.println ("s/\"" + compon.refer + "\"/\"CXZ" + Integer.toString (rotdrow * 10 + rotdcol) + "\"/w");
                }
            }
        }
        System.out.println ("s/\"CXZ/\"C/w");
    }
}
