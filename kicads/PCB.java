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

public class PCB {
    private boolean error;
    private SCM pcbscm;

    public SCM.ArrValue kicadpcb;
    public TreeMap<String,Network>  netsbyname;
    public TreeMap<Integer,Network> netsbynum;
    public TreeMap<String,Compon>   compons;

    public PCB (BufferedReader pcbrdr)
            throws Exception
    {
        // parse the scheme syntax
        pcbscm = new SCM (pcbrdr);
        SCM.Value value = pcbscm.topvalue ();

        // should be in form (kicad_pcb ...)
        if (! "kicad_pcb".equals (value.getarrname ())) {
            throw new Exception ("top-level not a 'kicad_pcb'");
        }
        kicadpcb = (SCM.ArrValue) value;

        // scan for networks and components
        netsbyname = new TreeMap<> ();
        netsbynum  = new TreeMap<> ();
        compons    = new TreeMap<> ();

        for (SCM.Value elem : kicadpcb.elems) {

            // (net <number> <name>)
            if ("net".equals (elem.getarrname ())) {
                SCM.ArrValue net = (SCM.ArrValue) elem;
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

        for (SCM.Value elem : kicadpcb.elems) {

            // (footprint ...)
            if ("footprint".equals (elem.getarrname ())) {
                SCM.ArrValue module = (SCM.ArrValue) elem;
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
                for (Pad pad : compon.compads) {
                    Network padnet = (pad == null) ? null : pad.padnet ();
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
                for (Pad pad : compon.compads) {
                    Network network = (pad == null) ? null : pad.padnet ();
                    if (network != null) {
                        network.netport = true;
                    }
                }
            }

            // if not a connector, mark nets connected to output pins as being driven
            else {
                for (Pad pad : compon.compads) {
                    Network network = (pad == null) ? null : pad.padnet ();
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

    public void save (PrintStream ps)
            throws Exception
    {
        pcbscm.save (ps);
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
        public String refer;        // (fp_text reference <ref> ...)
        public String value;        // (fp_text value <ref> ...)
        public Pad[] compads;       // (pad <idx> ... (net <num> ...) ...)
                                    // compads[] indexed by <idx>, might have nulls

        private SCM.NumValue atnodex;   // (at x y)
        private SCM.NumValue atnodey;

        public Compon (SCM.ArrValue module)
                throws Exception
        {
            value = "\"\"";
            int padsize = 0;
            HashMap<Integer,Pad> padhash = new HashMap<> ();
            for (SCM.Value moduleelem : module.elems) {
                if ("at".equals (moduleelem.getarrname ())) {
                    SCM.ArrValue atnode = (SCM.ArrValue) moduleelem;
                    atnodex = (SCM.NumValue) atnode.elems[1];
                    atnodey = (SCM.NumValue) atnode.elems[2];
                }
                if ("fp_text".equals (moduleelem.getarrname ())) {
                    SCM.ArrValue modulefptext = (SCM.ArrValue) moduleelem;
                    if (modulefptext.elems[1].assym ().equals ("reference")) {
                        refer = modulefptext.elems[2].assym ();
                    }
                    if (modulefptext.elems[1].assym ().equals ("value")) {
                        value = modulefptext.elems[2].assym ();
                    }
                }
                if ("pad".equals (moduleelem.getarrname ())) {
                    Pad pad = new Pad ((SCM.ArrValue) moduleelem);
                    pad.compon = this;
                    padhash.put (pad.padidx, pad);
                    if (padsize <= pad.padidx) padsize = pad.padidx + 1;
                }
            }
            compads = new Pad[padsize];
            for (Integer idx : padhash.keySet ()) {
                compads[idx] = padhash.get (idx);
            }
        }

        public boolean isconnector ()
        {
            return value.startsWith ("Conn");
        }

        public double atxin ()
        {
            return atnodex.num / 25.4;
        }

        public double atyin ()
        {
            return atnodey.num / 25.4;
        }

        public void atxin (double v)
        {
            atnodex.num = v * 25.4;
        }

        public void atyin (double v)
        {
            atnodey.num = v * 25.4;
        }
    }

    public class Pad {
        public Compon compon;
        public int padidx;
        public PinType pintype;
        public double atxin;    // (at x y)
        public double atyin;

        private SCM.NumValue modulepadnetnum; // (net <number>)

        public Pad (SCM.ArrValue modulepad)
                throws Exception
        {
            padidx = modulepad.elems[1].asint ();

            pintype = PinType.OTHER;
            atxin = Double.NaN;
            atyin = Double.NaN;

            for (SCM.Value modulepadelem : modulepad.elems) {
                if ("pintype".equals (modulepadelem.getarrname ())) {
                    SCM.ArrValue modulepadnet = (SCM.ArrValue) modulepadelem;
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
                    SCM.ArrValue modulepadnet = (SCM.ArrValue) modulepadelem;
                    modulepadnetnum = (SCM.NumValue) modulepadnet.elems[1];
                }
                if ("at".equals (modulepadelem.getarrname ())) {
                    SCM.ArrValue padat = (SCM.ArrValue) modulepadelem;
                    double v1 = ((SCM.NumValue) padat.elems[1]).num / 25.4;
                    double v2 = ((SCM.NumValue) padat.elems[2]).num / 25.4;
                    int ang = (padat.elems.length > 3) ? padat.elems[3].asint () : 0;
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

        public Network padnet () {
            if (modulepadnetnum == null) return null;
            int padnetnum = (int) modulepadnetnum.num;
            return netsbynum.get (padnetnum);
        }

        public void padnet (Network pn) {
            modulepadnetnum.num = pn.netnum;
            if (padnet () != pn) throw new RuntimeException ("bad network");
        }
    }
}
