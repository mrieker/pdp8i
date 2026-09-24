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

// Graphic PCB layout

// Put ICs on PCB in a grid with capacitors first
// Then run this program which shuffles the chips around to come up with shortest total trace lengths
// Press control-C to stop random shuffling

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.Random;
import java.util.TreeMap;

import sun.misc.Signal;
import sun.misc.SignalHandler;

public class Layout {
    public static boolean error;

    public static TreeMap<String,PCB.Network>  netsbyname;
    public static TreeMap<Integer,PCB.Network> netsbynum;
    public static PCB.Compon[] iccompons;
    public static TreeMap<String,PCB.Compon[]> chipsoftype;  // all 7400s, 7410s, etc

    public static SCM.ArrValue schemtop;
    public static SCM.ArrValue[] schemsyms;

    public static final int PIXPER20THIN = 5;   // pixels per 20th inch
    public static final int PIXPERINCH = 20 * PIXPER20THIN;

    public static volatile boolean runauto;
    public static int numcols;
    public static int numrows;
    public static int colwid20thin;
    public static int rowhit20thin;
    public static int colwidpix;
    public static int rowhitpix;
    public static double lowxin;
    public static double lowyin;
    public static Random randgen;

    private static TreeMap<String,EquivSubChip> equivsubchips;  // 7400 U38A is swappable with 7400 U64C etc
    private static TreeMap<String,EquivPad> equivpads;          // 7400 U12A pin 1 swappable with 7400 U12A pin 2 etc
    private static TreeMap<String,LinkedList<int[]>> swappedpads;

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

        // get lists of all chips on board by type (eg, 74AHC00, 74AC20)
        TreeMap<String,Integer> nchipsoftype = new TreeMap<> ();
        for (PCB.Compon compon : iccompons) {
            String type = compon.value;     // eg, "74AHC00"
            if (nchipsoftype.containsKey (type)) {
                nchipsoftype.put (type, nchipsoftype.get (type) + 1);
            } else {
                nchipsoftype.put (type, 1);
            }
        }
        chipsoftype = new TreeMap<> ();
        for (String type : nchipsoftype.keySet ()) {
            int n = nchipsoftype.get (type);
            PCB.Compon[] arr = new PCB.Compon[n];
            chipsoftype.put (type, arr);
            n = 0;
            for (PCB.Compon compon : iccompons) {
                if (type.equals (compon.value)) {
                    arr[n++] = compon;
                }
            }
        }

        // compute total trace length
        System.out.println ("totallen=" + inchstr (nettotallen ()));

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
            System.out.println (String.format ("chip=%-6s  x=%5.2f  y=%5.2f", compon.refer, (atx20thin / 20.0), (aty20thin / 20.0)));
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
        System.out.println ("numcols=" + numcols + " numrows=" + numrows + " colwid=" + inchstr (colwid20thin / 20.0) + " rowhit=" + inchstr (rowhit20thin / 20.0));
        lowxin = minatx20thin / 20.0;
        lowyin = minaty20thin / 20.0;

        colwidpix = colwid20thin * PIXPER20THIN;
        rowhitpix = rowhit20thin * PIXPER20THIN;

        SCM schematic = new SCM (new BufferedReader (new FileReader (modname + ".kicad_sch")));
        schemtop = (SCM.ArrValue) schematic.topvalue ();
        if (! schemtop.getarrname ().equals ("kicad_sch")) throw new Exception (modname + ".kicad_sch not a kicad_sch");
        schemsyms = schemtop.findsubarrays ("symbol");

        makeequivsubchips ();
        makeequivpads ();

        Signal.handle (new Signal ("INT"), new SignalHandler () {
            public void handle (Signal sig)
            {
                if (! runauto) {
                    System.err.println ("control-C aborting");
                    System.exit (1);
                }
                System.err.println ("control-C");
                runauto = false;
            }
        });

        runauto = true;
        int i = 0;
        randgen = new Random (123456789);
        double oldtotlen = nettotallen ();
        while (runauto) {

            // try swapping a pair of whole chips
            double newtotlen = doChipPositionSwap (oldtotlen);
            if (! Double.isNaN (newtotlen)) {
                oldtotlen = newtotlen;
            }

            // try swapping a pair of same-typed subchips
            for (String chiptype : equivsubchips.keySet ()) {
                newtotlen = doSubChipSwap (oldtotlen, chiptype);
                if (! Double.isNaN (newtotlen)) {
                    oldtotlen = newtotlen;
                }
            }

/*** no easy way to update schematic
            // try swapping a pair of same-function pads (eg, pin 1 and 2 of a 7400)
            for (String chiptype : equivpads.keySet ()) {
                newtotlen = doPadSwap (oldtotlen, chiptype);
                if (! Double.isNaN (newtotlen)) {
                    oldtotlen = newtotlen;
                }
            }
***/
        }

        // write out modified pcb
        System.out.println ("saving output file " + modname + "-new.kicad_pcb");
        pcb.save (new PrintStream (modname + "-new.kicad_pcb"));
        System.out.println ("saving output file " + modname + "-new.kicad_sch");
        schematic.save (new PrintStream (modname + "-new.kicad_sch"));
        System.out.println ("output files saved");

        System.out.println ("");
        System.out.println ("will have to apply these changes manually to schematic");
        swappedpads = new TreeMap<> ();
        runauto = true;
        randgen = new Random (987654321);
        while (runauto) {

            // try swapping a pair of same-function pads (eg, pin 1 and 2 of a 7400)
            for (String chiptype : equivpads.keySet ()) {
                double newtotlen = doPadSwap (oldtotlen, chiptype);
                if (! Double.isNaN (newtotlen)) {
                    oldtotlen = newtotlen;
                }
            }
        }

        System.out.println ("saving output file " + modname + "-new.swappedpads");
        PrintStream spps = new PrintStream (modname + "-new.swappedpads");
        for (String unum : swappedpads.keySet ()) {
            spps.print (unum + ":");
            for (int[] sp : swappedpads.get (unum)) {
                spps.print ("  (" + sp[0] + " " + sp[1] + ")");
            }
            spps.println ("");
        }
        spps.close ();
        System.out.println ("output files saved");
    }

    public static String inchstr (double inch)
    {
        int hundths = (int) Math.round (inch * 100.0);
        return Integer.toString (hundths / 100) + "." + Integer.toString (hundths % 100 + 100).substring (1);
    }

    // compute the total trace length (inches) to wire all networks to all connected pins
    public static double nettotallen ()
    {
        double totallen = 0;
        for (PCB.Network network : netsbyname.values ()) {
            if (goodnet (network)) {
                totallen += nettotallen (network);
            }
        }
        return totallen;
    }

    // compute the total trace length (inches) to wire a network to all connected pins
    public static class PadPair {
        public PCB.Pad pada;
        public PCB.Pad padb;
        public double dist ()
        {
            double ax = pada.compon.atxin () + pada.atxin;
            double ay = pada.compon.atyin () + pada.atyin;
            double bx = padb.compon.atxin () + padb.atxin;
            double by = padb.compon.atyin () + padb.atyin;
            return Math.hypot (ax - bx, ay - by);
        }
    }

    public static double nettotallen (PCB.Network network)
    {
        double nettotlen = 0;
        for (int j = 0; j < network.refdpads.length; j ++) {
            PCB.Pad firstpad = network.refdpads[j];
            if (firstpad.compon.refer.equals ("J6")) continue;
            if (firstpad.compon.refer.startsWith ("R")) continue;
            double firstpadatxin = firstpad.atxin + firstpad.compon.atxin ();
            double firstpadatyin = firstpad.atyin + firstpad.compon.atyin ();
            double closestdist = Double.NaN;
            for (int i = j; ++ i < network.refdpads.length;) {
                PCB.Pad pad = network.refdpads[i];
                double padatxin = pad.atxin + pad.compon.atxin ();
                double padatyin = pad.atyin + pad.compon.atyin ();
                double dist = Math.hypot (padatxin - firstpadatxin, padatyin - firstpadatyin);
                if (Double.isNaN (closestdist) || (closestdist > dist)) {
                    closestdist = dist;
                }
            }
            if (! Double.isNaN (closestdist)) {
                nettotlen += closestdist;
            }
        }
        return nettotlen;
    }

    // ignore power and unconnected networks
    public static boolean goodnet (PCB.Network network)
    {
        return
             (network != null) &&
            ! network.netname.equals ("VCC") &&
            ! network.netname.equals ("GND") &&
            ! network.netname.startsWith ("unconnected__");
    }

    /////////////////////////////////////
    //  SWAP POSITIONS OF WHOLE CHIPS  //
    /////////////////////////////////////

    private static boolean swap3;

    public static double doChipPositionSwap (double oldtotlen)
    {
        swap3 = ! swap3;
        if (swap3) {
            int irowa = randgen.nextInt (numrows);
            int irowb = randgen.nextInt (numrows);
            int irowc = randgen.nextInt (numrows);
            int icola = randgen.nextInt (numcols);
            int icolb = randgen.nextInt (numcols);
            int icolc = randgen.nextInt (numcols);
            double oldicax = icola * colwid20thin / 20.0 + lowxin;
            double oldicay = irowa * rowhit20thin / 20.0 + lowyin;
            double oldicbx = icolb * colwid20thin / 20.0 + lowxin;
            double oldicby = irowb * rowhit20thin / 20.0 + lowyin;
            double oldiccx = icolc * colwid20thin / 20.0 + lowxin;
            double oldiccy = irowc * rowhit20thin / 20.0 + lowyin;

            PCB.Compon ica = findChipOnGrid (irowa, icola);
            PCB.Compon icb = findChipOnGrid (irowb, icolb);
            PCB.Compon icc = findChipOnGrid (irowc, icolc);
            if (ica == icb) return Double.NaN;
            if (ica == icc) return Double.NaN;
            if (icc == icb) return Double.NaN;

            // don't move bus driver/receiver chips
/*
            if ((ica != null) && ica.value.endsWith ("540")) return Double.NaN;
            if ((icb != null) && icb.value.endsWith ("540")) return Double.NaN;
            if ((icc != null) && icc.value.endsWith ("540")) return Double.NaN;
*/

            // try swapping chip locations
            if (ica != null) {
                ica.atxin (oldicbx);
                ica.atyin (oldicby);
            }
            if (icb != null) {
                icb.atxin (oldiccx);
                icb.atyin (oldiccy);
            }
            if (icc != null) {
                icc.atxin (oldicax);
                icc.atyin (oldicay);
            }

            // see if overall trace lengths are shorter
            // if so, use the change
            double newtotlen = nettotallen ();
            if (oldtotlen > newtotlen) {
                System.out.println ("swap " +
                        (ica == null ? "empty" : ica.refer) + "(" + icola + "," + irowa + ") " +
                        (icb == null ? "empty" : icb.refer) + "(" + icolb + "," + irowb + ") " +
                        (icc == null ? "empty" : icc.refer) + "(" + icolc + "," + irowc + ") => " + newtotlen);
                return newtotlen;
            }

            // if same or longer, put it back
            if (ica != null) {
                ica.atxin (oldicax);
                ica.atyin (oldicay);
            }
            if (icb != null) {
                icb.atxin (oldicbx);
                icb.atyin (oldicby);
            }
            if (icc != null) {
                icc.atxin (oldiccx);
                icc.atyin (oldiccy);
            }
        } else {
            int irowa = randgen.nextInt (numrows);
            int irowb = randgen.nextInt (numrows);
            int icola = randgen.nextInt (numcols);
            int icolb = randgen.nextInt (numcols);
            double oldicax = icola * colwid20thin / 20.0 + lowxin;
            double oldicay = irowa * rowhit20thin / 20.0 + lowyin;
            double oldicbx = icolb * colwid20thin / 20.0 + lowxin;
            double oldicby = irowb * rowhit20thin / 20.0 + lowyin;

            PCB.Compon ica = findChipOnGrid (irowa, icola);
            PCB.Compon icb = findChipOnGrid (irowb, icolb);
            if (ica == icb) return Double.NaN;

            // don't move bus driver/receiver chips
/*
            if ((ica != null) && ica.value.endsWith ("540")) return Double.NaN;
            if ((icb != null) && icb.value.endsWith ("540")) return Double.NaN;
*/

            // try swapping chip locations
            if (ica != null) {
                ica.atxin (oldicbx);
                ica.atyin (oldicby);
            }
            if (icb != null) {
                icb.atxin (oldicax);
                icb.atyin (oldicay);
            }

            // see if overall trace lengths are shorter
            // if so, use the change
            double newtotlen = nettotallen ();
            if (oldtotlen > newtotlen) {
                System.out.println ("swap " +
                        (ica == null ? "empty" : ica.refer) + "(" + icola + "," + irowa + ") " +
                        (icb == null ? "empty" : icb.refer) + "(" + icolb + "," + irowb + ") => " + newtotlen);
                return newtotlen;
            }

            // if same or longer, put it back
            if (ica != null) {
                ica.atxin (oldicax);
                ica.atyin (oldicay);
            }
            if (icb != null) {
                icb.atxin (oldicbx);
                icb.atyin (oldicby);
            }
        }
        return Double.NaN;
    }

    private static PCB.Compon findChipOnGrid (int irow, int icol)
    {
        for (PCB.Compon compon : iccompons) {
            int x20thin = (int) Math.round ((compon.atxin () - lowxin) * 20.0);
            int y20thin = (int) Math.round ((compon.atyin () - lowyin) * 20.0);
            int chipcol = x20thin / colwid20thin;
            int chiprow = y20thin / rowhit20thin;
            if ((irow == chiprow) && (icol == chipcol)) return compon;
        }
        return null;
    }

    ////////////////////////////////////////////////
    //  SWAP SUBCHIPS AMONG IDENTICAL TYPE CHIPS  //
    ////////////////////////////////////////////////

    public static void makeequivsubchips ()
    {
        equivsubchips = new TreeMap<String,EquivSubChip> ();

        equivsubchips.put ("74AC10",   new EquivSubChip (new int[][] { new int[] { 1, 2, 13, 12 }, new int[] { 3, 4, 5, 6 }, new int[] { 9, 10, 11, 8 } }));
        equivsubchips.put ("74AC11",   new EquivSubChip (new int[][] { new int[] { 1, 2, 13, 12 }, new int[] { 3, 4, 5, 6 }, new int[] { 9, 10, 11, 8 } }));
        equivsubchips.put ("74HC27",   new EquivSubChip (new int[][] { new int[] { 1, 2, 13, 12 }, new int[] { 3, 4, 5, 6 }, new int[] { 9, 10, 11, 8 } }));
        equivsubchips.put ("74HC4075", new EquivSubChip (new int[][] { new int[] { 1, 2, 8, 9 }, new int[] { 3, 4, 5, 6 }, new int[] { 13, 12, 11, 10 } }));

        equivsubchips.put ("74AC20",   new EquivSubChip (new int[][] { new int[] { 1, 2, 4, 5, 6 }, new int[] { 9, 10, 12, 13, 8 } }));
        equivsubchips.put ("74HC21",   new EquivSubChip (new int[][] { new int[] { 1, 2, 4, 5, 6 }, new int[] { 9, 10, 12, 13, 8 } }));

        equivsubchips.put ("74AHC00",  new EquivSubChip (new int[][] { new int[] { 1, 2, 3 }, new int[] { 4, 5, 6 }, new int[] { 9, 10, 8 }, new int[] { 12, 13, 11 } }));
        equivsubchips.put ("74AHC02",  new EquivSubChip (new int[][] { new int[] { 2, 3, 1 }, new int[] { 5, 6, 4 }, new int[] { 8, 9, 10 }, new int[] { 11, 12, 13 } }));
        equivsubchips.put ("74AHC08",  new EquivSubChip (new int[][] { new int[] { 1, 2, 3 }, new int[] { 4, 5, 6 }, new int[] { 9, 10, 8 }, new int[] { 12, 13, 11 } }));
        equivsubchips.put ("74AHC32",  new EquivSubChip (new int[][] { new int[] { 1, 2, 3 }, new int[] { 4, 5, 6 }, new int[] { 9, 10, 8 }, new int[] { 12, 13, 11 } }));
        equivsubchips.put ("74AHC86",  new EquivSubChip (new int[][] { new int[] { 1, 2, 3 }, new int[] { 4, 5, 6 }, new int[] { 9, 10, 8 }, new int[] { 12, 13, 11 } }));

        equivsubchips.put ("74AHC04",  new EquivSubChip (new int[][] { new int[] { 1, 2 }, new int[] { 3, 4 }, new int[] { 5, 6 }, new int[] { 9, 8 }, new int[] { 11, 10 }, new int[] { 13, 12 } }));
    }

    public static class EquivSubChip {
        public int[][] equivs;

        public EquivSubChip (int[][] e)
        {
            equivs = e;
        }
    }

    // try swapping random chip/subchips of the given chiptype (74AHC00, etc)
    public static double doSubChipSwap (double oldtotlen, String chiptype)
            throws Exception
    {
        // get list of chips of the given type
        PCB.Compon[] ictypecompons = chipsoftype.get (chiptype);
        if (ictypecompons == null) return Double.NaN;
        int nictypecompons = ictypecompons.length;

        // get number of subchips per chip of that type (eg, 4 for 7400)
        EquivSubChip equiv = equivsubchips.get (chiptype);
        int nsubchipsperwholechip = equiv.equivs.length;

        // pick two random chip/subchips we will try to swap
        int iica = randgen.nextInt (nictypecompons * nsubchipsperwholechip);
        int iicb = randgen.nextInt (nictypecompons * nsubchipsperwholechip);

        // find which chips we are swapping
        PCB.Compon ica = ictypecompons[iica/nsubchipsperwholechip];
        PCB.Compon icb = ictypecompons[iicb/nsubchipsperwholechip];

        // find which subchip within those chips we are swapping
        int icsubchipa = iica % nsubchipsperwholechip;
        int icsubchipb = iicb % nsubchipsperwholechip;

        // swap the networks on each of the corresponding pads
        int npinspersubchip = equiv.equivs[0].length;       // eg, 3 for 7400
        boolean firstswap = true;
        while (true) {
            for (int i = 0; i < npinspersubchip; i ++) {
                int padnuma = equiv.equivs[icsubchipa][i];
                int padnumb = equiv.equivs[icsubchipb][i];
                PCB.Pad pada = ica.compads[padnuma];
                PCB.Pad padb = icb.compads[padnumb];
                swappadnets (pada, padb);
            }

            // just swapped them back after first time failed, return with stuff swapped back
            if (! firstswap) return Double.NaN;

            // first swap, if new total length less than old, return with subchips swapped
            double newtotlen = nettotallen ();
            if (newtotlen < oldtotlen) {
                // ica.refer = "U123"
                // icsubchipa = 0,1,2,... for A,B,C,...
                System.out.println ("swap " + ica.refer + (char)('A' + icsubchipa) + " " + icb.refer + (char)('A' + icsubchipb) + " => " + newtotlen);

                // update the schematic
                swapschemsubchips (ica.refer, icsubchipa + 1, icb.refer, icsubchipb + 1);

                return newtotlen;
            }

            // swap failed, loop back to swap them back where they were
            firstswap = false;
        }
    }

    // swap subchip references in the schematic file, eg, U35A <-> U72C
    public static void swapschemsubchips (String refa, int unita, String refb, int unitb)
    {
        for (SCM.ArrValue schvalarr : schemsyms) {

            // (symbol ... (unit 3) ... (property "Reference" "U118" ...) ...
            //   (instances (project "..." (path "..." (reference "U118") (unit 3)))))

            SCM.NumValue unitnumval  = null;
            SCM.NumValue unitnumval2 = null;
            SCM.StrValue refstrval   = null;
            SCM.StrValue refstrval2  = null;

            for (SCM.Value symval : schvalarr.elems) {
                String symvalarrname = symval.getarrname ();
                if (symvalarrname == null) continue;
                SCM.ArrValue symvalarr = (SCM.ArrValue) symval;

                // (unit 3)
                if ("unit".equals (symvalarrname)) {
                    unitnumval = (SCM.NumValue) symvalarr.elems[1];
                }

                // (property "Reference" "U118")
                if ("property".equals (symvalarrname) && "Reference".equals (symvalarr.elems[1].assym ())) {
                    refstrval = (SCM.StrValue) symvalarr.elems[2];
                }

                // (instances (project "..." (path "..." (reference "U118") (unit 3))))
                if ("instances".equals (symvalarrname)) {
                    SCM.ArrValue proj = symvalarr.findsubarray ("project");
                    if (proj != null) {
                        SCM.ArrValue path = proj.findsubarray ("path");
                        if (path != null) {
                            SCM.ArrValue refr = path.findsubarray ("reference");
                            SCM.ArrValue unit = path.findsubarray ("unit");
                            if (unit != null) unitnumval2 = (SCM.NumValue) unit.elems[1];
                            if (refr != null) refstrval2  = (SCM.StrValue) refr.elems[1];
                        }
                    }
                }
            }

            // should have all that stuff
            if ((refstrval == null) || (unitnumval == null) || (refstrval2 == null) || (unitnumval2 == null)) continue;
            if (! refstrval.str.equals (refstrval2.str) || (unitnumval.num != unitnumval2.num)) continue;

            // if (symbol ... (unit unita) ... (property "Reference" "refa" ...) ...)
            // change to            unitb                             refb
            if (refstrval.noquotes ().equals (refa) && (unitnumval.asint () == unita)) {
                refstrval.str  = refstrval2.str  = "\"" + refb + "\"";
                unitnumval.num = unitnumval2.num = unitb;
                continue;
            }

            // if (symbol ... (unit unitb) ... (property "Reference" "refb" ...) ...)
            // change to            unita                             refa
            if (refstrval.noquotes ().equals (refb) && (unitnumval.asint () == unitb)) {
                refstrval.str  = refstrval2.str  = "\"" + refa + "\"";
                unitnumval.num = unitnumval2.num = unita;
            }
        }
    }

    //////////////////////////////////////////////
    //  SWAP PADS AMONG IDENTICAL SUBCHIP PADS  //
    //////////////////////////////////////////////

    public static void makeequivpads ()
    {
        equivpads = new TreeMap<String,EquivPad> ();

        equivpads.put ("74AC10",   new EquivPad (new int[][] { new int[] { 1, 2, 13 }, new int[] { 3, 4, 5 }, new int[] { 9, 10, 11 } }));
        equivpads.put ("74AC11",   new EquivPad (new int[][] { new int[] { 1, 2, 13 }, new int[] { 3, 4, 5 }, new int[] { 9, 10, 11 } }));
        equivpads.put ("74HC27",   new EquivPad (new int[][] { new int[] { 1, 2, 13 }, new int[] { 3, 4, 5 }, new int[] { 9, 10, 11 } }));
        equivpads.put ("74HC4075", new EquivPad (new int[][] { new int[] { 1, 2, 8 }, new int[] { 3, 4, 5 }, new int[] { 13, 12, 11 } }));

        equivpads.put ("74AC20",   new EquivPad (new int[][] { new int[] { 1, 2, 4, 5 }, new int[] { 9, 10, 12, 13 } }));
        equivpads.put ("74HC21",   new EquivPad (new int[][] { new int[] { 1, 2, 4, 5 }, new int[] { 9, 10, 12, 13 } }));

        equivpads.put ("74AHC00",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13 } }));
        equivpads.put ("74AHC02",  new EquivPad (new int[][] { new int[] { 2, 3 }, new int[] { 5, 6 }, new int[] { 8, 9  }, new int[] { 11, 12 } }));
        equivpads.put ("74AHC08",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13 } }));
        equivpads.put ("74AHC32",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13 } }));
        equivpads.put ("74AHC86",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13 } }));

        equivpads.put ("74HC30",   new EquivPad (new int[][] { new int[] { 1, 2, 3, 4, 5, 6, 11, 12 } }));
    }

    public static class EquivPad {
        public int[][] equivs;

        public EquivPad (int[][] e)
        {
            equivs = e;
        }
    }

    // try swapping random pads within a subchip of the given chiptype (74AHC00, etc)
    public static double doPadSwap (double oldtotlen, String chiptype)
    {
        // get list of chips of the given type
        PCB.Compon[] ictypecompons = chipsoftype.get (chiptype);
        if (ictypecompons == null) return Double.NaN;
        int nictypecompons = ictypecompons.length;

        // get number of subchips per chip of that type (eg, 4 for 7400)
        EquivPad equiv = equivpads.get (chiptype);
        int nsubchipsperwholechip = equiv.equivs.length;

        // pick a random chip/subchip we will try to swap
        int iic = randgen.nextInt (nictypecompons * nsubchipsperwholechip);

        // find which chip we are swapping
        PCB.Compon ic = ictypecompons[iic/nsubchipsperwholechip];

        // find which subchip within that chip we are swapping
        int icsubchip = iic % nsubchipsperwholechip;

        // find which pads within the subchip we are swapping
        int npadspersubchip = equiv.equivs[icsubchip].length;   // eg, 2 for 7400
        int ipada = 0;
        int ipadb = 1;
        if (npadspersubchip > 2) {
            ipada = randgen.nextInt (npadspersubchip);
            ipadb = (randgen.nextInt (npadspersubchip - 1) + ipada + 1) % npadspersubchip;
        }

        // find which pads within the whole chip we are swapping
        ipada = equiv.equivs[icsubchip][ipada];
        ipadb = equiv.equivs[icsubchip][ipadb];
        PCB.Pad pada = ic.compads[ipada];
        PCB.Pad padb = ic.compads[ipadb];

        // swap the networks on the pads
        swappadnets (pada, padb);

        // if new total length less than old, return with pins swapped
        double newtotlen = nettotallen ();
        if (newtotlen < oldtotlen) {
            String subref = ic.refer + (char)('A' + icsubchip);     // eg, "U78C"
            System.out.println ("swap " + subref + " pads " + ipada + " " + ipadb + " => " + newtotlen);
            LinkedList<int[]> splist = swappedpads.get (subref);
            if (splist == null) {
                splist = new LinkedList<> ();
                swappedpads.put (subref, splist);
            }
            splist.addLast (new int[] { ipada, ipadb });
            return newtotlen;
        }

        // swap failed, swap them back where they were
        swappadnets (pada, padb);
        return Double.NaN;
    }

    // swap networks of two pads
    private static void swappadnets (PCB.Pad pada, PCB.Pad padb)
    {
        if (pada == padb) return;

        PCB.Network oldpadneta = pada.padnet ();
        PCB.Network oldpadnetb = padb.padnet ();
        pada.padnet (oldpadnetb);
        padb.padnet (oldpadneta);

        // update list of pads referenced by the networks
        for (int j = 0; j < oldpadneta.refdpads.length; j ++) {
            PCB.Pad oldpad = oldpadneta.refdpads[j];
            if (oldpad == pada) oldpadneta.refdpads[j] = padb;
            if (oldpad == padb) oldpadneta.refdpads[j] = pada;
        }
        for (int j = 0; j < oldpadnetb.refdpads.length; j ++) {
            PCB.Pad oldpad = oldpadnetb.refdpads[j];
            if (oldpad == pada) oldpadnetb.refdpads[j] = padb;
            if (oldpad == padb) oldpadnetb.refdpads[j] = pada;
        }
    }
}
