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

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.PrintStream;

public class Align {
    public static void main (String[] args)
            throws Exception
    {
        String modname = args[0];

        // parse the pcb file
        PCB pcb = new PCB (new BufferedReader (new FileReader (modname + ".kicad_pcb")));

        // align components to 20th inch
        int niccompons = 0;
        for (PCB.Compon compon : pcb.compons.values ()) {
            if (! compon.refer.startsWith ("H") && ! compon.value.equals ("LED")) {
                int atx20thin = (int) Math.round (compon.atxin () * 20);
                int aty20thin = (int) Math.round (compon.atyin () * 20);
                compon.atxin (atx20thin / 20.0);
                compon.atyin (aty20thin / 20.0);
            }
        }

        // write out modified pcb
        System.out.println ("saving output file " + modname + "-new.kicad_pcb");
        pcb.save (new PrintStream (modname + "-new.kicad_pcb"));
    }
}
