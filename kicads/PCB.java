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

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.TreeMap;

public class PCB {
    private boolean error;
    private BufferedReader inrdr;
    private int linum;

    public ArrValue kicadpcb;
    public TreeMap<String,Network>  netsbyname;
    public TreeMap<Integer,Network> netsbynum;
    public TreeMap<String,Compon>   compons;

    public PCB (BufferedReader pcbrdr)
            throws Exception
    {
        // parse the scheme syntax
        inrdr = pcbrdr;
        linum = 1;
        Value value = parseValue ();
        for (int ch; (ch = inrdr.read ()) >= 0;) {
            if (ch == '\n') linum ++;
            if (ch > ' ') {
                throw new Exception ("extra tokens at end at line " + linum);
            }
        }

        // should be in form (kicad_pcb ...)
        if (! "kicad_pcb".equals (value.getarrname ())) {
            throw new Exception ("top-level not a 'kicad_pcb'");
        }
        kicadpcb = (ArrValue) value;

        // scan for networks and components
        netsbyname = new TreeMap<> ();
        netsbynum  = new TreeMap<> ();
        compons    = new TreeMap<> ();

        for (Value elem : kicadpcb.elems) {

            // (net <number> <name>)
            if ("net".equals (elem.getarrname ())) {
                ArrValue net = (ArrValue) elem;
                Network network = new Network ();
                network.netnum  = net.elems[1].asint ();
                network.netname = net.elems[2].assym ();
                if (netsbyname.get (network.netname) != null) {
                    System.err.println ("duplicate network name " + network.netname);
                    error = true;
                }
                netsbynum.put (network.netnum, network);
                netsbyname.put (network.netname, network);
            }
        }

        for (Value elem : kicadpcb.elems) {

            // (footprint ...)
            if ("footprint".equals (elem.getarrname ())) {
                ArrValue module = (ArrValue) elem;
                Compon compon = new Compon (module);
                if (compon.refer != null) {
                    compons.put (compon.refer, compon);
                }
            }
        }

        // fill in what pads each network is connected to
        for (Network network : netsbynum.values ()) {
            LinkedList<Pad> pads = new LinkedList<> ();
            for (Compon compon : compons.values ()) {
                for (Pad pad : compon.pads) {
                    Network padnet = (pad == null) ? null : pad.padnet;
                    if (padnet == network) pads.addLast (pad);
                }
            }
            network.refdpads = pads.toArray (new Pad[pads.size()]);
        }

        // fill in networks referenced by the component
        for (String refer : compons.keySet ()) {
            Compon compon = compons.get (refer);

            // if it is a connector, mark all referenced networks as being ports to be listed in module statement
            if (compon.isconnector ()) {
                for (Pad pad : compon.pads) {
                    Network network = (pad == null) ? null : pad.padnet;
                    if (network != null) {
                        network.netport = true;
                    }
                }
            }

            // if not a connector, mark nets connected to output pins as being driven
            else {
                for (Pad pad : compon.pads) {
                    Network network = (pad == null) ? null : pad.padnet;
                    if (network != null) {
                        switch (pad.pintype) {
                            case OUTPUT: {
                                if (network.netrefs > 0) {
                                    System.err.println ("network " + network.netname + " has mixed hard and tristate drivers");
                                    error = true;
                                }
                                if (network.netrefs < 0) {
                                    System.err.println ("network " + network.netname + " has more than one hard driver");
                                    error = true;
                                }
                                network.netrefs = -1;
                                break;
                            }
                            case TRISTATE: {
                                if (network.netrefs < 0) {
                                    System.err.println ("network " + network.netname + " has mixed hard and tristate drivers");
                                    error = true;
                                }
                                network.netrefs = 1;
                                break;
                            }
                        }
                    }
                }
            }
        }
        if (error) throw new Exception ("error parsing pcb file");
    }

    // parse one value from inrdr
    private Value parseValue ()
            throws Exception
    {
        int ch;
        do {
            ch = inrdr.read ();
            if (ch < 0) throw new Exception ("end of file parsing token at line " + linum);
            if (ch == '\n') linum ++;
        } while (ch <= ' ');

        if (ch == ')') return null;

        if (ch == '(') {
            LinkedList<Value> elems = new LinkedList<> ();
            while (true) {
                Value elem = parseValue ();
                if (elem == null) break;
                elems.addLast (elem);
            }
            ArrValue arrval = new ArrValue ();
            arrval.elems = elems.toArray (new Value[elems.size()]);
            return arrval;
        }

        if (ch == '"') {
            StringBuilder sb = new StringBuilder ();
            sb.append ('"');
            while (true) {
                ch = inrdr.read ();
                if (ch < 0) throw new Exception ("end of file parsing token at line " + linum);
                if (ch == '\n') linum ++;
                if (ch == '"') break;
                switch (ch) {
                    case '\b': sb.append ("\\b"); break;
                    case '\n': sb.append ("\\n"); break;
                    case '\r': sb.append ("\\r"); break;
                    case '\t': sb.append ("\\t"); break;
                    case '\\': sb.append ('\\'); sb.append ((char) inrdr.read ()); break;
                    default: sb.append ((char) ch); break;
                }
            }
            sb.append ('"');
            StrValue strval = new StrValue ();
            strval.str = sb.toString ();
            return strval;
        }

        StringBuilder sb = new StringBuilder ();
        do {
            sb.append ((char) ch);
            inrdr.mark (1);
            ch = inrdr.read ();
            if (ch < 0) throw new Exception ("end of file parsing token at line " + linum);
            if (ch == '\n') linum ++;
        } while ((ch > ' ') && (ch != ')') && (ch != '"'));
        inrdr.reset ();
        String st = sb.toString ();
        try {
            double num = Double.parseDouble (st);
            NumValue numval = new NumValue ();
            numval.num = num;
            numval.str = st;
            return numval;
        } catch (NumberFormatException nfe) {
        }
        SymValue symval = new SymValue ();
        symval.sym = st;
        return symval;
    }

    // base value class

    public abstract class Value {
        public String getarrname () { return null; }    // if array with symbol for first element, first element name
        public String oneline () { return null; }       // if value is not an array, the string representation of the value
        public int asint () { return 0; }               // as an integer if possible
        public String assym () { return null; }         // as a symbol if possible
        public abstract void print (String indent);     // print the value on stdout
    }

    // parsed array (array of values between (...))

    public class ArrValue extends Value {
        public Value[] elems;

        @Override
        public String getarrname ()
        {
            if (elems.length < 1) return null;
            if (! (elems[0] instanceof SymValue)) return null;
            SymValue sv0 = (SymValue) elems[0];
            return sv0.sym;
        }

        @Override
        public void print (String indent)
        {
            boolean ononeline = true;
            for (Value elem : elems) {
                if (elem.oneline () == null) {
                    ononeline = false;
                    break;
                }
            }
            if (ononeline) {
                System.out.print (indent + "(");
                boolean first = true;
                for (Value elem : elems) {
                    if (! first) System.out.print (" ");
                    System.out.print (elem.oneline ());
                    first = false;
                }
                System.out.println (")");
            } else {
                boolean skipfirst = false;
                String firststring = elems[0].oneline ();
                if (firststring != null) {
                    System.out.println (indent + "(" + firststring);
                    skipfirst = true;
                } else {
                    System.out.println (indent + "(");
                }
                String ind = indent + "  ";
                for (Value elem : elems) {
                    if (! skipfirst) elem.print (ind);
                    skipfirst = false;
                }
                System.out.println (indent + ")");
            }
        }
    }

    // parsed numeric value

    public class NumValue extends Value {
        public double num;
        public String str;

        @Override
        public int asint ()
        {
            return (int) Math.round (num);
        }

        @Override
        public String oneline () { return str; }

        @Override
        public void print (String indent)
        {
            System.out.println (indent + str);
        }
    }

    // parsed quoted string

    public class StrValue extends Value {
        public String str;  // includes quotes and escapes

        @Override
        public int asint ()
        {
            return Integer.parseInt (noquotes ());
        }

        @Override
        public String assym ()
        {
            StringBuilder sb = new StringBuilder ();
            String nq = noquotes ();
            for (int i = 0; i < nq.length (); i ++) {
                char ch = nq.charAt (i);
                if ((i == 0) && (ch == '/')) continue;
                switch (ch) {
                case '>': sb.append ("gt"); break;
                case '=': sb.append ("eq"); break;
                case '<': sb.append ("lt"); break;
                default:
                    if ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".indexOf (ch) < 0) ch = '_';
                    sb.append (ch);
                    break;
                }
            }
            return sb.toString ();
        }

        public String noquotes ()
        {
            int i = str.startsWith ("\"") ? 1 : 0;
            int j = str.endsWith ("\"") ? 1 : 0;
            return str.substring (i, str.length () - j);
        }

        @Override
        public String oneline () { return str; }

        @Override
        public void print (String indent)
        {
            System.out.println (indent + str);
        }
    }

    // parsed symbol (unquoted string)

    public class SymValue extends Value {
        public String sym;

        @Override
        public String oneline () { return sym; }

        @Override
        public void print (String indent)
        {
            System.out.println (indent + sym);
        }
    }

    public enum PinType { OTHER, INPUT, OUTPUT, POWERIN, TRISTATE };

    // network

    public class Network {
        public int netnum;
        public String netname;
        public int netrefs;         // <0: has an OUTPUT pin
                                    // >0: multiple TRISTATE pins
        public boolean netport;     // is referenced by a connector
        public Pad[] refdpads;      // list of pads the network connects to

        public LinkedList<String> trinetnames = new LinkedList<> ();
    }

    // component

    public class Compon {
        public String refer;    // (fp_text reference <ref> ...)
        public String value;    // (fp_text value <ref> ...)
        public double atxin;    // (at x y)
        public double atyin;
        public Pad[] pads;      // (pad <idx> ... (net <num> ...) ...)

        public Compon (ArrValue module)
                throws Exception
        {
            value = "\"\"";
            int padsize = 0;
            HashMap<Integer,Pad> padhash = new HashMap<> ();
            for (Value moduleelem : module.elems) {
                if ("at".equals (moduleelem.getarrname ())) {
                    ArrValue moduleat = (ArrValue) moduleelem;
                    atxin = ((NumValue) moduleat.elems[1]).num / 25.4;
                    atyin = ((NumValue) moduleat.elems[2]).num / 25.4;
                }
                if ("fp_text".equals (moduleelem.getarrname ())) {
                    ArrValue modulefptext = (ArrValue) moduleelem;
                    if (modulefptext.elems[1].oneline ().equals ("reference")) {
                        refer = modulefptext.elems[2].assym ();
                    }
                    if (modulefptext.elems[1].oneline ().equals ("value")) {
                        value = modulefptext.elems[2].assym ();
                    }
                }
                if ("pad".equals (moduleelem.getarrname ())) {
                    Pad pad = new Pad ((ArrValue) moduleelem);
                    pad.compon = this;
                    padhash.put (pad.padidx, pad);
                    if (padsize <= pad.padidx) padsize = pad.padidx + 1;
                }
            }
            pads = new Pad[padsize];
            for (Integer idx : padhash.keySet ()) {
                pads[idx] = padhash.get (idx);
            }
        }

        public boolean isconnector ()
        {
            return value.startsWith ("Conn");
        }
    }

    public class Pad {
        public Compon compon;
        public int padidx;
        public Network padnet;
        public PinType pintype;
        public double atxin;    // (at x y)
        public double atyin;

        public Pad (ArrValue modulepad)
                throws Exception
        {
            padidx = modulepad.elems[1].asint ();

            pintype = PinType.OTHER;
            atxin = Double.NaN;
            atyin = Double.NaN;

            for (Value modulepadelem : modulepad.elems) {
                if ("pintype".equals (modulepadelem.getarrname ())) {
                    ArrValue modulepadnet = (ArrValue) modulepadelem;
                    String ptstr = modulepadnet.elems[1].assym ();
                    switch (ptstr) {
                        case "bidirectional": pintype = PinType.TRISTATE; break;
                        case "input": pintype = PinType.INPUT; break;
                        case "output": pintype = PinType.OUTPUT; break;
                        case "power_in": pintype = PinType.POWERIN; break;
                        case "tri_state": pintype = PinType.TRISTATE; break;
                    }
                }
                if ("net".equals (modulepadelem.getarrname ())) {
                    ArrValue modulepadnet = (ArrValue) modulepadelem;
                    int padnetnum = modulepadnet.elems[1].asint ();
                    padnet = netsbynum.get (padnetnum);
                }
                if ("at".equals (modulepadelem.getarrname ())) {
                    ArrValue padat = (ArrValue) modulepadelem;
                    double v1 = ((NumValue) padat.elems[1]).num / 25.4;
                    double v2 = ((NumValue) padat.elems[2]).num / 25.4;
                    int ang = 0;
                    if (padat.elems.length > 3) {
                        ang = (int) Math.round (((NumValue) padat.elems[3]).num);
                    }
                    switch (ang) {
                        case 0: {
                            atxin =   v1;
                            atyin =   v2;
                            break;
                        }
                        case 90: {
                            atxin =   v2;
                            atyin = - v1;
                            break;
                        }
                        default: throw new Exception ("unsupported angle " + ang);
                    }
                }
            }
        }
    }
}
