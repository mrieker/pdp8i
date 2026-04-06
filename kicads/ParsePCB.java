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

public class ParsePCB {
    public static boolean error;
    public static BufferedReader inrdr;
    public static int linum;

    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the scheme syntax
        inrdr = new BufferedReader (new InputStreamReader (System.in));
        linum = 1;
        Value value = parseValue ();
        for (int ch; (ch = inrdr.read ()) >= 0;) {
            if (ch == '\n') linum ++;
            if (ch > ' ') {
                throw new Exception ("extra tokens at end at line " + linum);
            }
        }

        // print it all out for debugging
        // value.print ("");

        // should be in form (kicad_pcb ...)
        if (! "kicad_pcb".equals (value.getarrname ())) {
            throw new Exception ("top-level not a 'kicad_pcb'");
        }
        ArrValue kicadpcb = (ArrValue) value;

        // scan for networks and components
        TreeMap<String,Network>  netsbyname = new TreeMap<> ();
        TreeMap<Integer,Network> netsbynum  = new TreeMap<> ();
        TreeMap<String,Compon>   compons    = new TreeMap<> ();

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

            // (footprint ...)
            if ("footprint".equals (elem.getarrname ())) {
                ArrValue module = (ArrValue) elem;
                Compon compon = new Compon (module);
                if (compon.refer != null) {
                    compons.put (compon.refer, compon);
                }
            }
        }

        // fill in network references
        for (String refer : compons.keySet ()) {
            Compon compon = compons.get (refer);

            // if it is a connector, mark all referenced networks as being ports to be listed in module statement
            if (compon.isconnector ()) {
                int npins = compon.padnets.length;
                for (int i = 0; i < npins; i ++) {
                    Network network = netsbynum.get (compon.padnets[i]);
                    if (network != null) network.netport = true;
                }
            }

            // if not a connector, mark nets connected to output pins as being driven
            else {
                int npins = compon.padnets.length;
                for (int i = 0; i < npins; i ++) {
                    Network network = netsbynum.get (compon.padnets[i]);
                    if (network != null) {
                        switch (compon.pintypes[i]) {
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

        // print networks
        // - if referenced by a connector, it is an input/output pin for the module
        // - if not refd by a connector, it is a wire
        System.out.println ("module " + modname + " (input zclock, zreset");
        char sep = ',';
        sep = printconpins (sep, netsbyname, "input");
        sep = printconpins (sep, netsbyname, "inout");
        sep = printconpins (sep, netsbyname, "output");
        System.out.println (");");

        System.out.println ("");
        for (Network network : netsbyname.values ()) {
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
            Compon compon = compons.get (refer);
            if (! compon.isconnector ()) {
                compon.print (netsbynum);
            }
        }

        // output assign statements for wired-and tri-state networks
        boolean first = true;
        for (Network network : netsbyname.values ()) {
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
                    if (! first) System.out.print (" | ");
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

    // print connector network names for a module statement
    //  input:
    //   sep = separator character
    //   netnames = all networks indexed by name
    //   keywrd = "input", "inout" or "output" : print network names for that type
    //  output:
    //   prints matching network names
    //   returns new separator char
    public static char printconpins (char sep, TreeMap<String,Network> netsbyname, String keywrd)
    {
        for (Network network : netsbyname.values ()) {
            if (network.netport && ! network.netname.startsWith ("unconnected")) {
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

    // parse one value from inrdr
    public static Value parseValue ()
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

    public static abstract class Value {
        public String getarrname () { return null; }    // if array with symbol for first element, first element name
        public String oneline () { return null; }       // if value is not an array, the string representation of the value
        public int asint () { return 0; }               // as an integer if possible
        public String assym () { return null; }         // as a symbol if possible
        public abstract void print (String indent);     // print the value on stdout
    }

    // parsed array (array of values between (...))

    public static class ArrValue extends Value {
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

    public static class NumValue extends Value {
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

    public static class StrValue extends Value {
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

    public static class SymValue extends Value {
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

    public static class Network {
        public int netnum;
        public String netname;
        public int netrefs;         // <0: has an OUTPUT pin
                                    // >0: multiple TRISTATE pins
        public boolean netport;     // is referenced by a connector

        public LinkedList<String> trinetnames = new LinkedList<> ();
    }

    // component

    public static class Compon {
        public String refer;    // (fp_text reference <ref> ...)
        public String value;    // (fp_text value <ref> ...)
        public int atx100;      // (at x y)
        public int aty100;
        public int[] padnets;   // (pad <idx> ... (net <num> ...) ...)
        public PinType[] pintypes;

        public Compon (ArrValue module)
        {
            value = "\"\"";
            int padsize = 0;
            HashMap<Integer,Integer> padnethash = new HashMap<> ();
            HashMap<Integer,PinType> pintypehash = new HashMap<> ();
            for (Value moduleelem : module.elems) {
                if ("at".equals (moduleelem.getarrname ())) {
                    ArrValue moduleat = (ArrValue) moduleelem;
                    atx100 = (int) Math.round (((NumValue) moduleat.elems[1]).num * 100);
                    aty100 = (int) Math.round (((NumValue) moduleat.elems[2]).num * 100);
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
                    ArrValue modulepad = (ArrValue) moduleelem;
                    int padidx = modulepad.elems[1].asint ();

                    PinType pintype = PinType.OTHER;
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
                            break;
                        }
                    }

                    int padnet = -1;
                    for (Value modulepadelem : modulepad.elems) {
                        if ("net".equals (modulepadelem.getarrname ())) {
                            ArrValue modulepadnet = (ArrValue) modulepadelem;
                            padnet = modulepadnet.elems[1].asint ();
                            break;
                        }
                    }

                    padnethash.put (padidx, padnet);
                    pintypehash.put (padidx, pintype);
                    if (padsize < padidx + 1) padsize = padidx + 1;
                }
            }
            padnets = new int[padsize];
            pintypes = new PinType[padsize];
            for (int i = 0; i < padsize; i ++) {
                padnets[i] = -1;
                pintypes[i] = PinType.OTHER;
            }
            for (Integer idx : padnethash.keySet ()) {
                padnets[idx] = padnethash.get (idx);
                pintypes[idx] = pintypehash.get (idx);
            }
        }

        public boolean isconnector ()
        {
            return value.startsWith ("Conn");
        }

        public void print (TreeMap<Integer,Network> netsbynum)
        {
            System.out.println ("");

            // print wire statements for each tri-state pin
            //  wire <netname>_<uname>p<pinnum>;
            for (int idx = 0; idx < padnets.length; idx ++) {
                int netnum = padnets[idx];
                if ((netnum >= 0) && (pintypes[idx] == PinType.TRISTATE)) {
                    Network network = netsbynum.get (netnum);
                    String tnn = network.netname + "_" + refer + "p" + idx;
                    network.trinetnames.add (tnn);
                    System.out.println ("    wire " + tnn + ";");
                }
            }

            // output module instantiation
            System.out.println ("    X" + value + " " + refer + " (");
            System.out.println ("        .zclock(zclock),");
            System.out.println ("        .zreset(zreset)");
            char sep = ',';
            for (int idx = 0; idx < padnets.length; idx ++) {
                int netnum = padnets[idx];
                if (netnum >= 0) {
                    Network network = netsbynum.get (netnum);
                    String netname = (network == null) ? Integer.toString (netnum) : network.netname;
                    if (pintypes[idx] == PinType.TRISTATE) {
                        String tnn = netname + "_" + refer + "p" + idx;
                        System.out.println (String.format ("        %c .p%di(%s) // TRISTATE", sep, idx, netname));
                        sep = ',';
                        System.out.println (String.format ("        %c .p%do(%s) // TRISTATE", sep, idx, tnn));
                        sep = ',';
                    } else {
                        System.out.println (String.format ("        %c .p%d(%s) // %s", sep, idx, netname, pintypes[idx].toString ()));
                        sep = ',';
                    }
                }
            }
            System.out.println ("    );");
        }
    }
}
