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
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.TreeMap;

public class SCM {
    private BufferedReader inrdr;
    private int linum;

    private Value topval;

    public SCM (BufferedReader inscm)
            throws Exception
    {
        inrdr  = inscm;
        linum  = 1;
        topval = parseValue ();
        for (int ch; (ch = inrdr.read ()) >= 0;) {
            if (ch == '\n') linum ++;
            if (ch > ' ') {
                throw new Exception ("extra tokens at end at line " + linum);
            }
        }
    }

    public Value topvalue () { return topval; }

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

        int toklinum = linum;

        if (ch == '(') {
            LinkedList<Value> elems = new LinkedList<> ();
            while (true) {
                Value elem = parseValue ();
                if (elem == null) break;
                elems.addLast (elem);
            }
            ArrValue arrval = new ArrValue ();
            arrval.linum = toklinum;
            arrval.endln = linum;
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
            strval.linum = toklinum;
            strval.str = sb.toString ();
            return strval;
        }

        StringBuilder sb = new StringBuilder ();
        int savlinum;
        do {
            sb.append ((char) ch);
            savlinum = linum;
            inrdr.mark (1);
            ch = inrdr.read ();
            if (ch < 0) throw new Exception ("end of file parsing token at line " + linum);
            if (ch == '\n') linum ++;
        } while ((ch > ' ') && (ch != ')') && (ch != '"'));
        inrdr.reset ();
        linum = savlinum;
        String st = sb.toString ();
        try {
            double num = Double.parseDouble (st);
            NumValue numval = new NumValue ();
            numval.linum = toklinum;
            numval.num = num;
            return numval;
        } catch (NumberFormatException nfe) {
        }
        SymValue symval = new SymValue ();
        symval.linum = toklinum;
        symval.sym = st;
        return symval;
    }

    public void save (PrintStream ps)
            throws Exception
    {
        Printer ptr = new Printer ();
        ptr.ps = ps;
        topval.print (ptr);
        ps.println ("");
    }

    private static class Printer {
        public int level = 0;
        public int linum = 1;
        public PrintStream ps;

        // print value string
        // maybe start a new line inserting corresponding indent
        public void printstr (int toklinum, String s)
        {
            if (linum < toklinum) {
                do ps.println ("");
                while (++ linum < toklinum);
                for (int i = 0; i < level; i ++) ps.print ("  ");
            }
            ps.print (s);
        }
    }

    // base value class

    public abstract class Value {
        public int linum;                               // line number of first character of token
        public String getarrname () { return null; }    // if array with symbol for first element, first element name
        public int asint () { return 0; }               // as an integer if possible
        public String assym () { return null; }         // as a symbol if possible
        public abstract void print (Printer ptr);       // print the value
    }

    // parsed array (array of values between (...))

    public class ArrValue extends Value {
        public Value[] elems;

        public int endln;

        @Override
        public String getarrname ()
        {
            return (elems.length < 1) ? null : elems[0].assym ();
        }

        @Override
        public void print (Printer ptr)
        {
            ptr.printstr (linum, "(");
            ptr.level ++;
            boolean first = true;
            for (Value elem : elems) {
                if (! first && (elem.linum <= ptr.linum)) {
                    ptr.printstr (elem.linum, " ");
                }
                elem.print (ptr);
                first = false;
            }
            ptr.level --;
            ptr.printstr (endln, ")");
        }

        // find uniquely named subarray
        public ArrValue findsubarray (String name)
        {
            ArrValue subarray = null;
            for (Value elem : elems) {
                if (name.equals (elem.getarrname ())) {
                    if (subarray != null) return null;
                    subarray = (ArrValue) elem;
                }
            }
            return subarray;
        }

        // find all like-named subarrays
        public ArrValue[] findsubarrays (String name)
        {
            ArrayList<ArrValue> subarrays = new ArrayList<> (elems.length);
            for (Value elem : elems) {
                if (name.equals (elem.getarrname ())) {
                    subarrays.add ((ArrValue) elem);
                }
            }
            if (subarrays.size () == 0) return null;
            return subarrays.toArray (new ArrValue[subarrays.size()]);
        }
    }

    // parsed numeric value

    public class NumValue extends Value {
        public double num;

        @Override
        public int asint ()
        {
            return (int) Math.round (num);
        }

        @Override
        public void print (Printer ptr)
        {
            String str;
            int ival = asint ();
            if ((double) ival == num) {
                str = Integer.toString (ival);
            } else {
                str = Double.toString (num);
                if (str.endsWith (".0")) str = str.substring (0, str.length () - 2);
            }
            ptr.printstr (linum, str);
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
        public void print (Printer ptr)
        {
            ptr.printstr (linum, str);
        }
    }

    // parsed symbol (unquoted string)

    public class SymValue extends Value {
        public String sym;

        @Override
        public String assym ()
        {
            return sym;
        }

        @Override
        public void print (Printer ptr)
        {
            ptr.printstr (linum, sym);
        }
    }
}
