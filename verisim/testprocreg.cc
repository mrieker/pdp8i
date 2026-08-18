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

// test physical procreg board
// runs on raspi plugged into tester board with physical procreg board plugged in

// sends random numbers to the board then compares with verilator equivalent

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "randbits.h"
#include "testlib.h"
#include "Vprocreg.h"

#define mp_memacsw mp__SCTR_4   // J2 P19

#define MAPMPIN(mp) do { vprregbits[mp_##mp] = &vprreg.mp; vprregnames[mp_##mp] = #mp; } while (0)

static int const procreg_impins[] = {
    mp__BRKWRM, mp__BUSINI, mp__CAINC, mp__INBUS_9, mp__INBUS_10, mp__INBUS_11, mp__IOP, mp__IOSKIP, mp__LNKTOG,
    mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3, mp__RUN, mp__SWCONT, mp__SWDEPOS, mp__SWEXAM, mp__SWLDAD,
    mp__TP1, mp__TP2, mp__TP3, mp__TP4, mp__TS1, mp__TS2, mp__TS3, mp__TS4, mp_aluq_0, mp_aluq_1, mp_aluq_2, mp_aluq_3,
    mp_aluq_4, mp_aluq_5, mp_aluq_6, mp_aluq_7, mp_aluq_8, mp_aluq_9, mp_aluq_10, mp_aluq_11, mp_cout, mp_memacsw, 0 };

static int const procreg_ompins[] = {
    mp__ACUM_0, mp__ACUM_1, mp__ACUM_2, mp__ACUM_3, mp__ACUM_4, mp__ACUM_5, mp__ACUM_6, mp__ACUM_7, mp__ACUM_8, mp__ACUM_9, mp__ACUM_10, mp__ACUM_11,
    mp__MADR_0, mp__MADR_1, mp__MADR_2, mp__MADR_3, mp__MADR_4, mp__MADR_5, mp__MADR_6, mp__MADR_7, mp__MADR_8, mp__MADR_9, mp__MADR_10, mp__MADR_11,
    mp__MBUF_0, mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, mp__MBUF_4, mp__MBUF_5, mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, mp__MBUF_9, mp__MBUF_10, mp__MBUF_11,
    mp__PCTR_0, mp__PCTR_1, mp__PCTR_2, mp__PCTR_3, mp__PCTR_4, mp__PCTR_5, mp__PCTR_6, mp__PCTR_7, mp__PCTR_8, mp__PCTR_9, mp__PCTR_10, mp__PCTR_11,
    mp__BRKCYC, mp__BWCOV, mp__IREG_9, mp__IREG_10, mp__IREG_11, mp__LINK, 0 };

static int const mps_aluq[] = {
    mp_aluq_11, mp_aluq_10, mp_aluq_9, mp_aluq_8,
    mp_aluq_7,  mp_aluq_6,  mp_aluq_5, mp_aluq_4,
    mp_aluq_3,  mp_aluq_2,  mp_aluq_1, mp_aluq_0,
    0 };

struct ProcReg {
    Vprocreg vprreg;            // verilated circuit board
    CData *vprregbits[256];     // pointers to vprreg elements, indexed by mpin
    char const *vprregnames[256];

    // sendables - sets verilog input pins
    void brkwrm    (bool v);
    void busini    (bool v);
    void cainc     (bool v);
    void inbus1109 (uint8_t v);
    void iop       (bool v);
    void ioskip    (bool v);
    void lnktog    (bool v);
    void majst     (uint8_t v);
    void run       (bool v);
    void swcont    (bool v);
    void swdepos   (bool v);
    void swexam    (bool v);
    void swldad    (bool v);
    void tp1       (bool v);
    void tp2       (bool v);
    void tp3       (bool v);
    void tp4       (bool v);
    void ts1       (bool v);
    void ts2       (bool v);
    void ts3       (bool v);
    void ts4       (bool v);
    void aluq      (uint16_t v);
    void cout      (bool v);
    void memacsw   (bool v);

    // write verilog registers
    void mbuf  (uint16_t v);
    void madr  (uint16_t v);
    void pctr  (uint16_t v);
    void ireg  (uint8_t  v);
    void bwcov (bool     v);

    // receiveables - reads verilog output pins
    uint16_t acum   ();
    uint16_t madr   ();
    uint16_t mbuf   ();
    uint16_t pctr   ();
    bool     brkcyc ();
    bool     bwcov  ();
    uint8_t  ireg   ();
    bool     link   ();

    ProcReg ();
    void init ();
    void genrand ();
    void update ();
    void printsent ();
    void printrcvd ();
    bool verify ();
};

static volatile bool ctrlcflag;
static ProcReg procreg;

static void sighand (int signum);

int main ()
{
    setlinebuf (stdout);

    signal (SIGINT, sighand);

    procreg.init ();

    // reset state of physical board and verilog so they match up
    // registers cleared by busini: acum link brkcyc
    // registers left as is by busini: mbuf madr pctr ireg bwcov

    printf ("reset\n");
    procreg.busini (1);
    procreg.update ();
    procreg.busini (0);
    procreg.update ();

    // read physical as-is registers then stuff the values into verilog registers
    procreg.mbuf (getmpins (mps__MBUF) ^ 07777);
    procreg.madr (getmpins (mps__MADR) ^ 07777);
    procreg.pctr (getmpins (mps__PCTR) ^ 07777);
    procreg.ireg (getmpins (mps__IREG) ^ 07777);
    procreg.bwcov (getmpin (mp__BWCOV) ^ 1);
    procreg.update ();  // get the verilog registers to soak through to the verilog edge connectors

    // should all match up now
    if (! procreg.verify ()) return 0;

    uint32_t ntest = 0;
    while (! ctrlcflag) {
        printf ("ntest=%10u\n", ++ ntest);

        procreg.genrand ();
        procreg.update ();

        procreg.ts4 (0);
        procreg.tp4 (0);
        procreg.ts1 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.tp1 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.ts1 (0);
        procreg.tp1 (0);
        procreg.ts2 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.tp2 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.ts2 (0);
        procreg.tp2 (0);
        procreg.ts3 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.tp3 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.ts3 (0);
        procreg.tp3 (0);
        procreg.ts4 (1);
        procreg.update ();
        if (! procreg.verify ()) break;

        procreg.genrand ();
        procreg.update ();

        procreg.tp4 (1);
        procreg.update ();
        if (! procreg.verify ()) break;
    }

    return 0;
}

static void sighand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}


ProcReg::ProcReg ()
{
    vprreg.VCC = 1;
    vprreg.GND = 0;

    memset (vprregbits,  0, sizeof vprregbits);
    memset (vprregnames, 0, sizeof vprregnames);

#define MAPMPIN(mp) do { vprregbits[mp_##mp] = &vprreg.mp; vprregnames[mp_##mp] = #mp; } while (0)

    MAPMPIN (_BRKWRM);
    MAPMPIN (_BUSINI);
    MAPMPIN (_CAINC);
    MAPMPIN (_INBUS_9);
    MAPMPIN (_INBUS_10);
    MAPMPIN (_INBUS_11);
    MAPMPIN (_IOP);
    MAPMPIN (_IOSKIP);
    MAPMPIN (_LNKTOG);
    MAPMPIN (_MAJST_0);
    MAPMPIN (_MAJST_1);
    MAPMPIN (_MAJST_2);
    MAPMPIN (_MAJST_3);
    MAPMPIN (_RUN);
    MAPMPIN (_SWCONT);
    MAPMPIN (_SWDEPOS);
    MAPMPIN (_SWEXAM);
    MAPMPIN (_SWLDAD);
    MAPMPIN (_TP1);
    MAPMPIN (_TP2);
    MAPMPIN (_TP3);
    MAPMPIN (_TP4);
    MAPMPIN (_TS1);
    MAPMPIN (_TS2);
    MAPMPIN (_TS3);
    MAPMPIN (_TS4);
    MAPMPIN (aluq_0);
    MAPMPIN (aluq_1);
    MAPMPIN (aluq_2);
    MAPMPIN (aluq_3);
    MAPMPIN (aluq_4);
    MAPMPIN (aluq_5);
    MAPMPIN (aluq_6);
    MAPMPIN (aluq_7);
    MAPMPIN (aluq_8);
    MAPMPIN (aluq_9);
    MAPMPIN (aluq_10);
    MAPMPIN (aluq_11);
    MAPMPIN (cout);
    MAPMPIN (memacsw);

    MAPMPIN (_ACUM_0);
    MAPMPIN (_ACUM_1);
    MAPMPIN (_ACUM_2);
    MAPMPIN (_ACUM_3);
    MAPMPIN (_ACUM_4);
    MAPMPIN (_ACUM_5);
    MAPMPIN (_ACUM_6);
    MAPMPIN (_ACUM_7);
    MAPMPIN (_ACUM_8);
    MAPMPIN (_ACUM_9);
    MAPMPIN (_ACUM_10);
    MAPMPIN (_ACUM_11);
    MAPMPIN (_MADR_0);
    MAPMPIN (_MADR_1);
    MAPMPIN (_MADR_2);
    MAPMPIN (_MADR_3);
    MAPMPIN (_MADR_4);
    MAPMPIN (_MADR_5);
    MAPMPIN (_MADR_6);
    MAPMPIN (_MADR_7);
    MAPMPIN (_MADR_8);
    MAPMPIN (_MADR_9);
    MAPMPIN (_MADR_10);
    MAPMPIN (_MADR_11);
    MAPMPIN (_MBUF_0);
    MAPMPIN (_MBUF_1);
    MAPMPIN (_MBUF_2);
    MAPMPIN (_MBUF_3);
    MAPMPIN (_MBUF_4);
    MAPMPIN (_MBUF_5);
    MAPMPIN (_MBUF_6);
    MAPMPIN (_MBUF_7);
    MAPMPIN (_MBUF_8);
    MAPMPIN (_MBUF_9);
    MAPMPIN (_MBUF_10);
    MAPMPIN (_MBUF_11);
    MAPMPIN (_PCTR_0);
    MAPMPIN (_PCTR_1);
    MAPMPIN (_PCTR_2);
    MAPMPIN (_PCTR_3);
    MAPMPIN (_PCTR_4);
    MAPMPIN (_PCTR_5);
    MAPMPIN (_PCTR_6);
    MAPMPIN (_PCTR_7);
    MAPMPIN (_PCTR_8);
    MAPMPIN (_PCTR_9);
    MAPMPIN (_PCTR_10);
    MAPMPIN (_PCTR_11);
    MAPMPIN (_BRKCYC);
    MAPMPIN (_BWCOV);
    MAPMPIN (_IREG_9);
    MAPMPIN (_IREG_10);
    MAPMPIN (_IREG_11);
    MAPMPIN (_LINK);

    brkwrm    (0);
    busini    (0);
    cainc     (0);
    inbus1109 (0);
    iop       (0);
    ioskip    (0);
    lnktog    (0);
    majst     (0);
    run       (0);
    swcont    (0);
    swdepos   (0);
    swexam    (0);
    swldad    (0);
    tp1       (0);
    tp2       (0);
    tp3       (0);
    tp4       (0);
    ts1       (0);
    ts2       (0);
    ts3       (0);
    ts4       (0);
    aluq      (0);
    cout      (0);
    memacsw   (0);
}

void ProcReg::init ()
{
    // make masks of input and output pins so we know what words to send/receive on i2c busses
    setmpinmask (boardipinmask, procreg_impins);
    setmpinmask (boardopinmask, procreg_ompins);
    mcpsetdir ();
}

// fill all inputs except ts1,2,3,4, tp1,2,3,4, busini, with random values
void ProcReg::genrand ()
{
    brkwrm    (randbits  (1));
    cainc     (randbits  (1));
    inbus1109 (randbits  (3));
    iop       (randbits  (1));
    ioskip    (randbits  (1));
    lnktog    (randbits  (1));
    majst     (randbits  (1));
    run       (randbits  (1));
    swcont    (randbits  (1));
    swdepos   (randbits  (1));
    swexam    (randbits  (1));
    swldad    (randbits  (1));
    aluq      (randbits (12));
    cout      (randbits  (1));
    memacsw   (randbits  (1));
}

// send values to circuit board then retrieve the results
void ProcReg::update ()
{
    int mp;
    for (int const *impins = procreg_impins; (mp = *impins) != 0; impins ++) {
        CData *v = vprregbits[mp];
        setmpin (mp, *v);
    }

    // send bits to circuit board
    mcpsend ();

    // send random bits to verilog then compute reply
    // clock it through 500nS of chips-varns.v delays
    for (int i = 0; i < 100; i ++) {
        vprreg.eval ();
        vprreg.zclock = 1;
        vprreg.eval ();
        vprreg.zclock = 0;
    }

    // receive bits from circuit board
    mcprecv ();
}

void ProcReg::printsent ()
{
    printf ("raspi->board: brkwrm=%o busini=%o cainc=%o inbus=%04o iop=%o ioskip=%o lnktog=%o majst=%X run=%o swcont=%o swdepos=%o swexam=%o swldad=%o tp=%o%o%o%o ts=%o%o%o%o aluq=%04o cout=%o memacsw=%o\n",
        getmpin  (mp__BRKWRM)  ^ 1,
        getmpin  (mp__BUSINI)  ^ 1,
        getmpin  (mp__CAINC)   ^ 1,
        getmpins (mps__INBUS)  ^ 07777,
        getmpin  (mp__IOP)     ^ 1,
        getmpin  (mp__IOSKIP)  ^ 1,
        getmpin  (mp__LNKTOG)  ^ 1,
        getmpins (mps__MAJST)  ^ 15,
        getmpin  (mp__RUN)     ^ 1,
        getmpin  (mp__SWCONT)  ^ 1,
        getmpin  (mp__SWDEPOS) ^ 1,
        getmpin  (mp__SWEXAM)  ^ 1,
        getmpin  (mp__SWLDAD)  ^ 1,
        getmpin  (mp__TP1)     ^ 1,
        getmpin  (mp__TP2)     ^ 1,
        getmpin  (mp__TP3)     ^ 1,
        getmpin  (mp__TP4)     ^ 1,
        getmpin  (mp__TS1)     ^ 1,
        getmpin  (mp__TS2)     ^ 1,
        getmpin  (mp__TS3)     ^ 1,
        getmpin  (mp__TS4)     ^ 1,
        getmpins (mps_aluq),
        getmpin  (mp_cout),
        getmpin  (mp_memacsw));
}

void ProcReg::printrcvd ()
{
    printf ("board->raspi: acum=%04o brkcyc=%o bwcov=%o ireg=%o link=%o madr=%04o mbuf=%04o pctr=%04o\n",
        getmpins (mps__ACUM)   ^ 07777,
        getmpin   (mp__BRKCYC) ^ 1,
        getmpin   (mp__BWCOV)  ^ 1,
        getmpins (mps__IREG)   ^ 7,
        getmpin   (mp__LINK)   ^ 1,
        getmpins (mps__MADR)   ^ 07777,
        getmpins (mps__MBUF)   ^ 07777,
        getmpins (mps__PCTR)   ^ 07777);
}

// compare to make sure the replies are the same
bool ProcReg::verify ()
{
    bool error = false;
    int mp;
    for (int const *ompins = procreg_ompins; (mp = *ompins) != 0; ompins ++) {
        CData *v = vprregbits[mp];  // get pointer to verilator struct
        bool vsb = *v;              // get verilated pin value
        bool vis = getmpin (mp);    // get physical pin from mcp23017
        if (vis != vsb) {
            int cp = mptocp[mp];    // error, get connector pin
            int jack = (cp >> 6) + 1;
            int jpin = cp & 63;
            fprintf (stderr, "pin %-8s J%dP%02d is %d, should be %d\n", vprregnames[mp], jack, jpin, vis, vsb);
            error = true;
        }
    }
    return ! error;
}


// write verilog register
// these all assume all input pins are 0
// ...and return with all input pins 0

void ProcReg::mbuf  (uint16_t v)
{
    aluq (v);       // set flipflop data inputs
    vprreg.eval ();
    tp1 (1);        // MBUF clocks on all TP1s
    vprreg.eval ();
    aluq (0);       // restore input pins 0
    tp1 (0);
    vprreg.eval ();

    if (mbuf () != v) abort ();
}

void ProcReg::madr  (uint16_t v)
{
    aluq (v);       // set flipflop inputs
    vprreg.eval ();
    tp4 (1);        // MADR clocks on TP4 with MAJST<3> = 0
    vprreg.eval ();
    aluq (0);       // restore input pins 0
    tp4 (0);
    vprreg.eval ();

    if (madr () != v) abort ();
}

void ProcReg::pctr  (uint16_t v)
{
    aluq (v);       // set flipflop inputs
    vprreg.eval ();
    tp3 (1);        // PCTR clock on TP3 with RUN = 0
    vprreg.eval ();
    aluq (0);       // restore input pins 0
    tp3 (0);
    vprreg.eval ();

    if (pctr () != v) abort ();
}

void ProcReg::ireg  (uint8_t  v)
{
    inbus1109 (v);  // set flipflop inputs
    majst (1);      // set MAJST = FETCH
    vprreg.eval ();
    tp1 (1);        // IREG clocks on TP1 with MAJST = FETCH
    vprreg.eval ();
    inbus1109 (0);  // restore input pins 0
    majst (0);
    tp1 (0);
    vprreg.eval ();

    if (ireg () != v) abort ();
}

void ProcReg::bwcov (bool     v)
{
    cout (v);       // set flipflop input
    majst (3);      // set MAJST = EXEC
    vprreg.eval ();
    tp2 (1);        // BWCOV clocks on TP2 with MAJST = EXEC or WRDCT
    vprreg.eval ();
    inbus1109 (0);  // restore input pins 0
    majst (0);
    tp2 (0);
    vprreg.eval ();

    if (bwcov () != v) abort ();
}

// write verilog input pins
void ProcReg::brkwrm    (bool v) { vprreg._BRKWRM  = ! v; }
void ProcReg::busini    (bool v) { vprreg._BUSINI  = ! v; }
void ProcReg::cainc     (bool v) { vprreg._CAINC   = ! v; }
void ProcReg::iop       (bool v) { vprreg._IOP     = ! v; }
void ProcReg::ioskip    (bool v) { vprreg._IOSKIP  = ! v; }
void ProcReg::lnktog    (bool v) { vprreg._LNKTOG  = ! v; }
void ProcReg::run       (bool v) { vprreg._RUN     = ! v; }
void ProcReg::swcont    (bool v) { vprreg._SWCONT  = ! v; }
void ProcReg::swdepos   (bool v) { vprreg._SWDEPOS = ! v; }
void ProcReg::swexam    (bool v) { vprreg._SWEXAM  = ! v; }
void ProcReg::swldad    (bool v) { vprreg._SWLDAD  = ! v; }
void ProcReg::tp1       (bool v) { vprreg._TP1     = ! v; }
void ProcReg::tp2       (bool v) { vprreg._TP2     = ! v; }
void ProcReg::tp3       (bool v) { vprreg._TP3     = ! v; }
void ProcReg::tp4       (bool v) { vprreg._TP4     = ! v; }
void ProcReg::ts1       (bool v) { vprreg._TS1     = ! v; }
void ProcReg::ts2       (bool v) { vprreg._TS2     = ! v; }
void ProcReg::ts3       (bool v) { vprreg._TS3     = ! v; }
void ProcReg::ts4       (bool v) { vprreg._TS4     = ! v; }
void ProcReg::cout      (bool v) { vprreg.cout     =   v; }
void ProcReg::memacsw   (bool v) { vprreg.memacsw  =   v; }

void ProcReg::inbus1109 (uint8_t v)
{
    vprreg._INBUS_9  = (~ v >> 0) & 1;
    vprreg._INBUS_10 = (~ v >> 1) & 1;
    vprreg._INBUS_11 = (~ v >> 2) & 1;
}
void ProcReg::majst     (uint8_t v)
{
    vprreg._MAJST_0  = (~ v >> 0) & 1;
    vprreg._MAJST_1  = (~ v >> 1) & 1;
    vprreg._MAJST_2  = (~ v >> 2) & 1;
    vprreg._MAJST_3  = (~ v >> 3) & 1;
}
void ProcReg::aluq      (uint16_t v)
{
    vprreg.aluq_0  = (v >>  0) & 1;
    vprreg.aluq_1  = (v >>  1) & 1;
    vprreg.aluq_2  = (v >>  2) & 1;
    vprreg.aluq_3  = (v >>  3) & 1;
    vprreg.aluq_4  = (v >>  4) & 1;
    vprreg.aluq_5  = (v >>  5) & 1;
    vprreg.aluq_6  = (v >>  6) & 1;
    vprreg.aluq_7  = (v >>  7) & 1;
    vprreg.aluq_8  = (v >>  8) & 1;
    vprreg.aluq_9  = (v >>  9) & 1;
    vprreg.aluq_10 = (v >> 10) & 1;
    vprreg.aluq_11 = (v >> 11) & 1;
}

// read verilog output pins
uint16_t ProcReg::acum   ()
{
    return
        (((uint16_t) vprreg._ACUM_11 << 11) |
         ((uint16_t) vprreg._ACUM_10 << 10) |
         ((uint16_t) vprreg._ACUM_9  <<  9) |
         ((uint16_t) vprreg._ACUM_8  <<  8) |
         ((uint16_t) vprreg._ACUM_7  <<  7) |
         ((uint16_t) vprreg._ACUM_6  <<  6) |
         ((uint16_t) vprreg._ACUM_5  <<  5) |
         ((uint16_t) vprreg._ACUM_4  <<  4) |
         ((uint16_t) vprreg._ACUM_3  <<  3) |
         ((uint16_t) vprreg._ACUM_2  <<  2) |
         ((uint16_t) vprreg._ACUM_1  <<  1) |
         ((uint16_t) vprreg._ACUM_0  <<  0)) ^ 07777;
}
uint16_t ProcReg::madr   ()
{
    return
        (((uint16_t) vprreg._MADR_11 << 11) |
         ((uint16_t) vprreg._MADR_10 << 10) |
         ((uint16_t) vprreg._MADR_9  <<  9) |
         ((uint16_t) vprreg._MADR_8  <<  8) |
         ((uint16_t) vprreg._MADR_7  <<  7) |
         ((uint16_t) vprreg._MADR_6  <<  6) |
         ((uint16_t) vprreg._MADR_5  <<  5) |
         ((uint16_t) vprreg._MADR_4  <<  4) |
         ((uint16_t) vprreg._MADR_3  <<  3) |
         ((uint16_t) vprreg._MADR_2  <<  2) |
         ((uint16_t) vprreg._MADR_1  <<  1) |
         ((uint16_t) vprreg._MADR_0  <<  0)) ^ 07777;
}
uint16_t ProcReg::mbuf   ()
{
    return
        (((uint16_t) vprreg._MBUF_11 << 11) |
         ((uint16_t) vprreg._MBUF_10 << 10) |
         ((uint16_t) vprreg._MBUF_9  <<  9) |
         ((uint16_t) vprreg._MBUF_8  <<  8) |
         ((uint16_t) vprreg._MBUF_7  <<  7) |
         ((uint16_t) vprreg._MBUF_6  <<  6) |
         ((uint16_t) vprreg._MBUF_5  <<  5) |
         ((uint16_t) vprreg._MBUF_4  <<  4) |
         ((uint16_t) vprreg._MBUF_3  <<  3) |
         ((uint16_t) vprreg._MBUF_2  <<  2) |
         ((uint16_t) vprreg._MBUF_1  <<  1) |
         ((uint16_t) vprreg._MBUF_0  <<  0)) ^ 07777;
}
uint16_t ProcReg::pctr   ()
{
    return
        (((uint16_t) vprreg._PCTR_11 << 11) |
         ((uint16_t) vprreg._PCTR_10 << 10) |
         ((uint16_t) vprreg._PCTR_9  <<  9) |
         ((uint16_t) vprreg._PCTR_8  <<  8) |
         ((uint16_t) vprreg._PCTR_7  <<  7) |
         ((uint16_t) vprreg._PCTR_6  <<  6) |
         ((uint16_t) vprreg._PCTR_5  <<  5) |
         ((uint16_t) vprreg._PCTR_4  <<  4) |
         ((uint16_t) vprreg._PCTR_3  <<  3) |
         ((uint16_t) vprreg._PCTR_2  <<  2) |
         ((uint16_t) vprreg._PCTR_1  <<  1) |
         ((uint16_t) vprreg._PCTR_0  <<  0)) ^ 07777;
}
bool     ProcReg::brkcyc () { return ! vprreg._BRKCYC; }
bool     ProcReg::bwcov  () { return ! vprreg._BWCOV;  }
uint8_t  ProcReg::ireg   ()
{
    return
        (((uint8_t) vprreg._IREG_11 << 2) |
         ((uint8_t) vprreg._IREG_10 << 1) |
         ((uint8_t) vprreg._IREG_9  << 0)) ^ 7;
}
bool     ProcReg::link   () { return ! vprreg._LINK;   }
