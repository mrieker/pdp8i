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
// Click on graphics screen to stop random shuffling to perform manual shuffling
// Close graphics screen to write result out

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.Random;
import java.util.TreeMap;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.GridLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import javax.swing.JCheckBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;

public class Layout {
    public static boolean error;

    public static TreeMap<String,PCB.Network>  netsbyname;
    public static TreeMap<Integer,PCB.Network> netsbynum;
    public static PCB.Compon[] iccompons;
    public static TreeMap<String,PCB.Compon[]> chipsoftype;  // all 7400s, 7410s, etc

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

    private static volatile boolean editcomplete;
    private static Font labelfont = new Font ("Serif", Font.PLAIN, 10);
    private static JFrame jframe;
    private static Object editinprog = new Object ();
    private static Object syncit = new Object ();
    private static TreeMap<String,JCheckBox> typeckboxes;

    private static TreeMap<String,EquivSubChip> equivsubchips;  // 7400 U38A is swappable with 7400 U64C etc
    private static TreeMap<String,EquivPad> equivpads;          // 7400 U12A pin 1 swappable with 7400 U12A pin 2 etc

    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the pcb file
        PCB pcb = new PCB (new BufferedReader (new InputStreamReader (System.in)));
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
        int numnets = 0;
        for (PCB.Network network : netsbyname.values ()) {
            if (goodnet (network) && (numnets <= network.netnum)) numnets = network.netnum + 1;
        }
        nettotlencache = new NetTotLen[numnets];
        System.err.println ("totallen=" + inchstr (nettotallen ()));

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
        System.err.println ("numcols=" + numcols + " numrows=" + numrows + " colwid=" + inchstr (colwid20thin / 20.0) + " rowhit=" + inchstr (rowhit20thin / 20.0));
        lowxin = minatx20thin / 20.0;
        lowyin = minaty20thin / 20.0;

        // make chip editing grid panel
        colwidpix = colwid20thin * PIXPER20THIN;
        rowhitpix = rowhit20thin * PIXPER20THIN;
        MyPanel mypanel = new MyPanel ();
        Dimension psize = new Dimension (numcols * colwidpix, numrows * rowhitpix);
        mypanel.setMaximumSize (psize);
        mypanel.setMinimumSize (psize);
        mypanel.setPreferredSize (psize);
        mypanel.setLayout (null);

        // make checkboxes for every chip type
        typeckboxes = new TreeMap<> ();
        for (PCB.Compon compon : iccompons) {
            // value = '74AHC00' etc
            if (! typeckboxes.containsKey (compon.value)) {
                JCheckBox typeckbox = new JCheckBox (compon.value);
                typeckbox.addChangeListener (mypanel);
                typeckboxes.put (compon.value, typeckbox);
            }
        }
        int ntypeckboxes = typeckboxes.size ();
        JPanel typecbpanel = new JPanel (new GridLayout (ntypeckboxes, 1));
        for (JCheckBox typeckbox : typeckboxes.values ()) {
            typecbpanel.add (typeckbox);
        }

        JPanel toppanel = new JPanel (new FlowLayout ());
        toppanel.add (mypanel);
        toppanel.add (typecbpanel);

        jframe = new JFrame ("Layout");
        updtotnetlen ();
        jframe.setDefaultCloseOperation (JFrame.DISPOSE_ON_CLOSE);
        jframe.add (toppanel);
        jframe.addWindowListener (new WindowAdapter () {
            @Override
            public void windowClosing (WindowEvent we)
            {
                System.err.println ("window closed");
                synchronized (editinprog) {
                    runauto = false;
                    editcomplete = true;
                    editinprog.notifyAll ();
                }
            }
        });
        jframe.pack ();
        jframe.setVisible (true);

        makeequivsubchips ();
        makeequivpads ();

        runauto = true;
        int i = 0;
        randgen = new Random (123456789);
        double oldtotlen = nettotallen ();
        while (runauto) {
            double newtotlen = doChipPositionSwap (oldtotlen);
            if (! Double.isNaN (newtotlen)) {
                oldtotlen = newtotlen;
                updtotnetlen ();
                mypanel.repaint ();
            }
            for (String chiptype : equivsubchips.keySet ()) {
                newtotlen = doSubChipSwap (oldtotlen, chiptype);
                if (! Double.isNaN (newtotlen)) {
                    oldtotlen = newtotlen;
                    updtotnetlen ();
                    mypanel.repaint ();
                }
            }
            for (String chiptype : equivpads.keySet ()) {
                newtotlen = doPadSwap (oldtotlen, chiptype);
                if (! Double.isNaN (newtotlen)) {
                    oldtotlen = newtotlen;
                    updtotnetlen ();
                    mypanel.repaint ();
                }
            }
        }
/***
        // wait for jframe closed
        synchronized (editinprog) {
            while (! editcomplete) {
                editinprog.wait ();
            }
        }
***/
        // write out modified pcb
        System.err.println ("saving output file");
        pcb.save (System.out);
        System.err.println ("output file saved");
    }

    public static String inchstr (double inch)
    {
        int hundths = (int) Math.round (inch * 100.0);
        return Integer.toString (hundths / 100) + "." + Integer.toString (hundths % 100 + 100).substring (1);
    }

    private static class MyPanel extends JPanel implements ChangeListener {

        public MyPanel ()
        { }

        @Override  // ChangeListener
        public void stateChanged (ChangeEvent e)
        {
            repaint ();
        }

        @Override
        protected void paintComponent (Graphics g)
        {
            g.setColor (Color.GRAY);
            g.fillRect (0, 0, numcols * colwidpix, numrows * rowhitpix);

            // draw all placeables in their current position
            // highlight any selected one in yellow, others are white background
            g.setFont (labelfont);

            synchronized (syncit) {

                for (PCB.Compon compon : iccompons) {
                    g.setColor (Color.WHITE);
                    int xpixleft = (int) Math.round ((compon.atxin () - lowxin) * PIXPERINCH);
                    int ypixtop  = (int) Math.round ((compon.atyin () - lowyin) * PIXPERINCH);
                    g.fillRoundRect (xpixleft, ypixtop, colwidpix, rowhitpix, 10, 10);
                    g.setColor (Color.BLACK);
                    g.drawRoundRect (xpixleft, ypixtop, colwidpix, rowhitpix, 10, 10);
                    g.drawString (compon.refer + "  " + compon.value, xpixleft + 10, ypixtop + 20);
                }

                // draw interconnections used to compute total trace lengths
                // if any checkboxes checked, only draw lines connected to enabled chips
                boolean anychecked = false;
                for (JCheckBox typeckbox : typeckboxes.values ()) {
                    anychecked |= typeckbox.isSelected ();
                }
                for (NetTotLen ntl : nettotlencache) {
                    if (ntl != null) {
                        for (PadPair pp : ntl.padpairs) {
                            PCB.Pad pada = pp.pada;
                            PCB.Pad padb = pp.padb;
                            PCB.Compon compa = pada.compon;
                            PCB.Compon compb = padb.compon;
                            boolean drawit = ! anychecked;
                            if (! drawit) {
                                JCheckBox cba = typeckboxes.get (compa.value);
                                if (cba != null) drawit = cba.isSelected ();
                            }
                            if (! drawit) {
                                JCheckBox cbb = typeckboxes.get (compb.value);
                                if (cbb != null) drawit = cbb.isSelected ();
                            }
                            if (drawit) {
                                g.setColor (Color.MAGENTA);
                                int ax = (int) Math.round ((compa.atxin () + pada.atxin) * PIXPERINCH);
                                int ay = (int) Math.round ((compa.atyin () + pada.atyin) * PIXPERINCH);
                                int bx = (int) Math.round ((compb.atxin () + padb.atxin) * PIXPERINCH);
                                int by = (int) Math.round ((compb.atyin () + padb.atyin) * PIXPERINCH);
                                g.drawLine (ax, ay, bx, by);
                            }
                        }
                    }
                }
            }

            // draw the grid with green lines
            g.setColor (Color.GREEN);
            for (int row = 0; row <= numrows; row ++) {
                g.drawLine (0, row * rowhitpix, numcols * colwidpix, row * rowhitpix);
            }
            for (int col = 0; col <= numcols; col ++) {
                g.drawLine (col * colwidpix, 0, col * colwidpix, numrows * rowhitpix);
            }
        }
    }

    // display total network length
    private static void updtotnetlen ()
    {
        jframe.setTitle ("Layout " + inchstr (nettotallen ()));
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

    public static class NetTotLen {
        public LinkedList<PadPair> padpairs = new LinkedList<> ();
        public double nettotlen ()
        {
            double ntl = 0;
            for (PadPair pp : padpairs) {
                ntl += pp.dist ();
            }
            return ntl;
        }
    }

    private static NetTotLen[] nettotlencache;

    public static double nettotallen (PCB.Network network)
    {
        NetTotLen ntl = new NetTotLen ();
        for (int j = 0; j < network.refdpads.length; j ++) {
            PCB.Pad firstpad = network.refdpads[j];
            double firstpadatxin = firstpad.atxin + firstpad.compon.atxin ();
            double firstpadatyin = firstpad.atyin + firstpad.compon.atyin ();
            PCB.Pad closestpad = null;
            double closestdist = Double.NaN;
            for (int i = j; ++ i < network.refdpads.length;) {
                PCB.Pad pad = network.refdpads[i];
                double padatxin = pad.atxin + pad.compon.atxin ();
                double padatyin = pad.atyin + pad.compon.atyin ();
                double dist = Math.hypot (padatxin - firstpadatxin, padatyin - firstpadatyin);
                if (Double.isNaN (closestdist) || (closestdist > dist)) {
                    closestpad  = pad;
                    closestdist = dist;
                }
            }
            if (closestpad != null) {
                PadPair pp = new PadPair ();
                pp.pada = firstpad;
                pp.padb = closestpad;
                ntl.padpairs.addLast (pp);
            }
        }
        nettotlencache[network.netnum] = ntl;
        return ntl.nettotlen ();
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

    public static double doChipPositionSwap (double oldtotlen)
    {
        int irowa = randgen.nextInt (numrows);
        int irowb = randgen.nextInt (numrows);
        int icola = randgen.nextInt (numcols);
        int icolb = randgen.nextInt (numcols);
        double oldicax = icola * colwid20thin / 20.0 + lowxin;
        double oldicay = irowa * rowhit20thin / 20.0 + lowyin;
        double oldicbx = icolb * colwid20thin / 20.0 + lowxin;
        double oldicby = irowb * rowhit20thin / 20.0 + lowyin;

        synchronized (syncit) {

            PCB.Compon ica = findChipOnGrid (irowa, icola);
            PCB.Compon icb = findChipOnGrid (irowb, icolb);
            if (ica == icb) return Double.NaN;

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
                System.err.println ("swap " +
                        (ica == null ? "" : ica.refer) + "(" + icola + "," + irowa + ") " +
                        (icb == null ? "" : icb.refer) + "(" + icolb + "," + irowb + ") => " + newtotlen);
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
            return Double.NaN;
        }
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
    {
        return Double.NaN;
/***
        // get list of chips of the given type
        PCB.Compon[] ictypecompons = chipsoftype.get (chiptype);
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
            synchronized (syncit) {
                for (int i = 0; i < npinspersubchip; i ++) {
                    int padnuma = equiv.equivs[icsubchipa][i];
                    int padnumb = equiv.equivs[icsubchipb][i];
                    PCB.Pad pada = ica.compads[padnuma];
                    PCB.Pad padb = icb.compads[padnumb];
                    swappadnets (pada, padb);
                }
            }

            // just swapped them back after first time failed, return with stuff swapped back
            if (! firstswap) return Double.NaN;

            // first swap, if new total length less than old, return with pins swapped
            double newtotlen = nettotallen ();
            if (newtotlen < oldtotlen) {
                System.err.println ("swap " + ica.refer + (char)('A' + icsubchipa) + " " + icb.refer + (char)('A' + icsubchipb) + " => " + newtotlen);
                return newtotlen;
            }

            // swap failed, loop back to swap them back where they were
            firstswap = false;
        }
***/
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

        equivpads.put ("74AHC00",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13, 11 } }));
        equivpads.put ("74AHC02",  new EquivPad (new int[][] { new int[] { 2, 3 }, new int[] { 5, 6 }, new int[] { 8, 9  }, new int[] { 11, 12, 13 } }));
        equivpads.put ("74AHC08",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13, 11 } }));
        equivpads.put ("74AHC32",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13, 11 } }));
        equivpads.put ("74AHC86",  new EquivPad (new int[][] { new int[] { 1, 2 }, new int[] { 4, 5 }, new int[] { 9, 10 }, new int[] { 12, 13, 11 } }));
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
        return Double.NaN;
/***
        // get list of chips of the given type
        PCB.Compon[] ictypecompons = chipsoftype.get (chiptype);
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
        synchronized (syncit) {
            swappadnets (pada, padb);
        }

        // if new total length less than old, return with pins swapped
        double newtotlen = nettotallen ();
        if (newtotlen < oldtotlen) {
            System.err.println ("swap " + ic.refer + (char)('A' + icsubchip) + " pads " + ipada + " " + ipadb + " => " + newtotlen);
            return newtotlen;
        }

        // swap failed, swap them back where they were
        synchronized (syncit) {
            swappadnets (pada, padb);
        }
        return Double.NaN;
***/
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
