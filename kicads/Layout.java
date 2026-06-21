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
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
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

    public static final int PIXPER20THIN = 5;   // pixels per 20th inch
    public static final int PIXPERINCH = 20 * PIXPER20THIN;

    public static boolean runauto;
    public static int numcols;
    public static int numrows;
    public static int colwid20thin;
    public static int rowhit20thin;
    public static int colwidpix;
    public static int rowhitpix;
    public static double lowxin;
    public static double lowyin;

    private static boolean editcomplete;
    private static Font labelfont = new Font ("Serif", Font.PLAIN, 10);
    private static JFrame jframe;
    private static Object editinprog = new Object ();
    private static Object syncit = new Object ();
    private static TreeMap<String,JCheckBox> typeckboxes;

    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the pcb file
        PCB pcb = new PCB (new BufferedReader (new InputStreamReader (System.in)));
        netsbyname = pcb.netsbyname;
        netsbynum  = pcb.netsbynum;

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

    /***
        for (PCB.Compon compon : iccompons) {
            System.err.println ("comp " + compon.refer + " (" + compon.atxin + "," + compon.atyin + ")");
            for (PCB.Pad pad : compon.pads) {
                if (pad == null) continue;
                System.err.println ("   p" + pad.padidx + " (" + pad.atxin + "," + pad.atyin + ") " + (pad.padnet == null ? "" : pad.padnet.netname));
            }
        }
    ***/

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
        int colwid20thin = (maxatx20thin - minatx20thin) / (numcols - 1);
        int rowhit20thin = (maxaty20thin - minaty20thin) / (numrows - 1);
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
        ////jframe.setSize (psize);
        jframe.setDefaultCloseOperation (JFrame.DISPOSE_ON_CLOSE);
        jframe.add (toppanel);
        jframe.addWindowListener (new WindowAdapter () {
            @Override
            public void windowClosing (WindowEvent we)
            {
                synchronized (editinprog) {
                    editcomplete = true;
                    editinprog.notifyAll ();
                }
            }
        });
        jframe.pack ();
        jframe.setVisible (true);

        runauto = true;
        int i = 0;
        Random rand = new Random ();
        double oldtotlen = nettotallen ();
        while (runauto) {
            ++ i;
            int iica = rand.nextInt (niccompons);
            int iicb = rand.nextInt (niccompons);
            PCB.Compon ica = iccompons[iica];
            PCB.Compon icb = iccompons[iicb];
            double oldicax = ica.atxin ();
            double oldicay = ica.atyin ();
            double oldicbx = icb.atxin ();
            double oldicby = icb.atyin ();
            synchronized (syncit) {
                ica.atxin (oldicbx);
                ica.atyin (oldicby);
                icb.atxin (oldicax);
                icb.atyin (oldicay);
                invalNetTotLen (ica);
                invalNetTotLen (icb);
                double newtotlen = nettotallen ();
                if (oldtotlen > newtotlen) {
                    System.err.println ("[" + i + "] swap " + ica.refer + " " + icb.refer + " => " +  newtotlen);
                    oldtotlen = newtotlen;
                    updtotnetlen ();
                    mypanel.repaint ();
                } else {
                    if (i % 1000 == 0) System.err.println ("[" + i + "] newtotlen=" + newtotlen);
                    ica.atxin (oldicax);
                    ica.atyin (oldicay);
                    icb.atxin (oldicbx);
                    icb.atyin (oldicby);
                    invalNetTotLen (ica);
                    invalNetTotLen (icb);
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
        pcb.save (System.out);
    }

    public static String inchstr (double inch)
    {
        int hundths = (int) Math.round (inch * 100.0);
        return Integer.toString (hundths / 100) + "." + Integer.toString (hundths % 100 + 100).substring (1);
    }


    private static class MyPanel extends JPanel implements ChangeListener, MouseListener {

        private PCB.Compon mousecompon;

        public MyPanel ()
        {
            addMouseListener (this);
        }

        @Override  // ChangeListener
        public void stateChanged (ChangeEvent e)
        {
            repaint ();
        }

        @Override  // MouseListener
        public void mouseClicked (MouseEvent me)
        {
            runauto = false;

            int mousedownxpix = me.getX ();
            int mousedownypix = me.getY ();

            // find component being clicked if any
            for (PCB.Compon compon : iccompons) {
                int xpixleft = (int) Math.round ((compon.atxin () - lowxin) * PIXPERINCH);
                int ypixtop  = (int) Math.round ((compon.atyin () - lowyin) * PIXPERINCH);
                int xpixrite = xpixleft + colwidpix;
                int ypixbot  = ypixtop  + rowhitpix;
                if ((mousedownxpix > xpixleft) && (mousedownxpix < xpixrite) && (mousedownypix > ypixtop) && (mousedownypix < ypixbot)) {
                    System.err.println ("clicked on " + compon.refer);
                    if (mousecompon == null) {

                        // first click with nothing else clicked, select the clicked-on component
                        System.err.println ("  selected " + compon.refer);
                        mousecompon = compon;
                    } else if (mousecompon == compon) {

                        // second click on same component, deselect the component
                        System.err.println ("  deselected " + compon.refer);
                        mousecompon = null;
                    } else {
                        System.err.println ("  swap with " + mousecompon.refer);

                        // swap position of the two components
                        double oldatxin = mousecompon.atxin ();
                        double oldatyin = mousecompon.atyin ();
                        double newatxin = compon.atxin ();
                        double newatyin = compon.atyin ();
                        mousecompon.atxin (newatxin);
                        mousecompon.atyin (newatyin);
                        compon.atxin (oldatxin);
                        compon.atyin (oldatyin);

                        // invalidate all connected network lengths
                        invalNetTotLen (mousecompon);
                        invalNetTotLen (compon);

                        // recompute network lengths
                        updtotnetlen ();
                    }

                    // redraw with new selections/positions
                    repaint ();
                    break;
                }
            }
        }

        @Override  // MouseListener
        public void mouseEntered (MouseEvent me)
        { }

        @Override  // MouseListener
        public void mouseExited (MouseEvent me)
        { }

        @Override  // MouseListener
        public void mousePressed (MouseEvent me)
        { }

        @Override  // MouseListener
        public void mouseReleased (MouseEvent me)
        { }

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
                    g.setColor ((compon == mousecompon) ? Color.YELLOW : Color.WHITE);
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
                                g.setColor ((compa == mousecompon) || (compb == mousecompon) ? Color.BLUE : Color.MAGENTA);
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
        NetTotLen ntl = nettotlencache[network.netnum];
        if (ntl == null) {
            ntl = new NetTotLen ();
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
        }
        return ntl.nettotlen ();
    }

    // invalidate network total lengths that are connected to the component
    private static void invalNetTotLen (PCB.Compon compon)
    {
        for (PCB.Pad pad : compon.pads) {
            PCB.Network network = (pad == null) ? null : pad.padnet;
            if ((network != null) && (network.netnum < nettotlencache.length)) {
                nettotlencache[network.netnum] = null;
            }
        }
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
}
