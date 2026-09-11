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

// test physical procseq board
// runs on raspi plugged into tester board with physical procseq board plugged in
// assumes wfidisable jumper is disconnected on physical board, ie, WFI instruction enabled

// sends random numbers to the board then compares with verilator equivalent

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "../ccode/randbits.h"
#include "testlib.h"
#include "Vprocseq.h"

#define mp_memacsw mp__SCTR_4           // J2 P19

#define MAPMPIN(mp) do { vprseqbits[mp_##mp] = &vprseq.mp; vprseqnames[mp_##mp] = #mp; } while (0)

static int const procseq_impins[] = {
    mp__BRKRQST, mp__CLOCK, mp__CYCLE3, mp__INTINH, mp__INTRQST, mp__IREG_9, mp__IREG_10, mp__IREG_11, 
    mp__MBUF_0, mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, mp__MBUF_4, mp__MBUF_5, mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, 
    mp__RESET, mp__SWCONT, mp__SWDEPOS, mp__SWEXAM, mp__SWLDAD, mp__SWSINST, mp__SWSSTEP, mp__SWSTART, 0 };

static int const procseq_ompins[] = {
    mp__BRKGNTO, mp__BUSINI, mp__ION, mp__IOP, mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3, mp__PAUSE,
    mp__RUN, mp__TP1, mp__TP2, mp__TP3, mp__TP4, mp__TS1, mp__TS2, mp__TS3, mp__TS4,
    mp_memacsw, mp_nxtms_0, mp_nxtms_1, mp_nxtms_2, mp_nxtms_3, 0 };

static int const mps_nxtms[] = { mp_nxtms_3, mp_nxtms_2, mp_nxtms_1, mp_nxtms_0, 0 };

struct ProcSeq {
    Vprocseq vprseq;            // verilated circuit board
    CData *vprseqbits[256];     // pointers to vprseq elements, indexed by mpin
    char const *vprseqnames[256];

    // sendables
    void brkrqst (bool v);
    void clock   (bool v);
    void cycle3  (bool v);
    void intinh  (bool v);
    void intrqst (bool v);
    void ireg    (uint8_t  v);
    void mbuf    (uint16_t v);
    void reset   (bool v);
    void swcont  (bool v);
    void swdepos (bool v);
    void swexam  (bool v);
    void swldad  (bool v);
    void swsinst (bool v);
    void swsstep (bool v);
    void swstart (bool v);

    bool clock   ();
    bool intrqst ();
    uint8_t  ireg ();
    uint16_t mbuf ();

    // receiveables
    bool     brkgnto ();
    bool     busini  ();
    bool     ion     ();
    bool     iop     ();
    uint8_t  majst   ();
    bool     pause   ();
    bool     run     ();
    bool     tp1     ();
    bool     tp2     ();
    bool     tp3     ();
    bool     tp4     ();
    bool     ts1     ();
    bool     ts2     ();
    bool     ts3     ();
    bool     ts4     ();
    bool     memacsw ();
    uint8_t  nxtms   ();

    ProcSeq ();
    void init ();
    void genrand ();
    void update ();
    void printsent ();
    void printrcvd ();
    bool verify ();
    void puqueffs ();

    enum SwitchState {
        SS_NONE  = 0,
        SS_CONT  = 1,
        SS_DEPOS = 2,
        SS_EXAM  = 3,
        SS_LDAD  = 4,
        SS_START = 5
    };

    int switchtimer;
    SwitchState switchstate;

    void feedback ();
};

static volatile bool ctrlcflag;
static ProcSeq procseq;

static void sighand (int signum);

/***
static void pausekb ()
{
    char buff[16];
    printf (" > ");
    fflush (stdout);
    if (fgets (buff, sizeof buff, stdin) == NULL) exit (0);
}
***/

int main ()
{
    setlinebuf (stdout);

    signal (SIGINT, sighand);

    procseq.init ();

    // reset state of physical board and verilog so they match up
    printf ("reset\n");
    procseq.reset (1);
    procseq.update ();
    procseq.reset (0);
    procseq.update ();
    printf ("phys board _TP4 = %o\n", getmpin (mp__TP4));
    printf ("verilator  procseq.tp4 = %o\n", procseq.vprseq.procseq__DOT__tp4);
    printf ("verilator  _TP4_o = %o\n", procseq.vprseq._TP4_o);
    procseq.printsent ();
    procseq.printrcvd ();
    if (! procseq.verify ()) return 0;

    uint32_t ntest = 0;
    while (! ctrlcflag) {
        if ((++ ntest % 1000 == 0) || (procseq.majst () == 7)) {
            printf ("%10u swst=%d ireg=%o mbuf=%03o intrqst=%d => ion=%d run=%d majst=%X\n",
                ntest, procseq.switchstate, procseq.ireg (), procseq.mbuf (), procseq.intrqst (),
                procseq.ion (), procseq.run (), procseq.majst ());
        }

///     printf ("\n");
///     printf ("- - - - - - - - - - - - - - - - %10u\n", ++ ntest);

        // clock has been low for a while, scramble the inputs
///     printf ("\n");
///     printf ("  sending random inputs\n");
        procseq.genrand ();
        procseq.update ();
///     procseq.printsent ();

        // now they are stable, drive clock high, everything else the same
///     printf ("  driving clock high\n");
        procseq.clock (1);
        procseq.update ();

        // print and verify state
///     printf ("  resultant state\n");
////    procseq.puqueffs ();
///     procseq.printrcvd ();
////    if (ntest >= 335) pausekb ();
        if (! procseq.verify ()) break;

        // clock has been high for a while, scramble the inputs
///     printf ("\n");
///     printf ("  sending random inputs\n");
        procseq.genrand ();
        procseq.update ();
///     procseq.printsent ();

        // now they are stable, drive clock low, everything else the same
///     printf ("  driving clock low\n");
        procseq.clock (0);
        procseq.update ();

        // print and verify state
///     printf ("  resultant state\n");
////    procseq.puqueffs ();
///     procseq.printrcvd ();
////    if (ntest >= 335) pausekb ();
        if (! procseq.verify ()) break;
    }

    return 0;
}

static void sighand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}


ProcSeq::ProcSeq ()
{
    vprseq.VCC = 1;
    vprseq.GND = 0;

    vprseq._wfidisab = 1;   // assume WFI disable jumper not installed

    memset (vprseqbits,  0, sizeof vprseqbits);
    memset (vprseqnames, 0, sizeof vprseqnames);

#define MAPMPIN(mp) do { vprseqbits[mp_##mp] = &vprseq.mp; vprseqnames[mp_##mp] = #mp; } while (0)

    MAPMPIN (_BRKRQST);
    MAPMPIN (_CLOCK);
    MAPMPIN (_CYCLE3);
    MAPMPIN (_INTINH);
    MAPMPIN (_INTRQST);
    MAPMPIN (_IREG_9);
    MAPMPIN (_IREG_10);
    MAPMPIN (_IREG_11);
    MAPMPIN (_MBUF_0);
    MAPMPIN (_MBUF_1);
    MAPMPIN (_MBUF_2);
    MAPMPIN (_MBUF_3);
    MAPMPIN (_MBUF_4);
    MAPMPIN (_MBUF_5);
    MAPMPIN (_MBUF_6);
    MAPMPIN (_MBUF_7);
    MAPMPIN (_MBUF_8);
    MAPMPIN (_RESET);
    MAPMPIN (_SWCONT);
    MAPMPIN (_SWDEPOS);
    MAPMPIN (_SWEXAM);
    MAPMPIN (_SWLDAD);
    MAPMPIN (_SWSINST);
    MAPMPIN (_SWSSTEP);
    MAPMPIN (_SWSTART);

    MAPMPIN (_BRKGNTO);
    MAPMPIN (_BUSINI);
    MAPMPIN (_ION);
    MAPMPIN (_IOP);
    MAPMPIN (_MAJST_0);
    MAPMPIN (_MAJST_1);
    MAPMPIN (_MAJST_2);
    MAPMPIN (_MAJST_3);
    MAPMPIN (_PAUSE);
    MAPMPIN (_RUN);
    MAPMPIN (_TP1);
    MAPMPIN (_TP2);
    MAPMPIN (_TP3);
    MAPMPIN (_TP4);
    MAPMPIN (_TS1);
    MAPMPIN (_TS2);
    MAPMPIN (_TS3);
    MAPMPIN (_TS4);
    MAPMPIN (memacsw);
    MAPMPIN (nxtms_0);
    MAPMPIN (nxtms_1);
    MAPMPIN (nxtms_2);
    MAPMPIN (nxtms_3);

    brkrqst (0);
    clock   (0);
    cycle3  (0);
    intinh  (0);
    intrqst (0);
    ireg    (0);
    mbuf    (0);
    reset   (0);
    swcont  (0);
    swdepos (0);
    swexam  (0);
    swldad  (0);
    swsinst (0);
    swsstep (0);
    swstart (0);

    switchtimer = 0;
    switchstate = SS_NONE;
}

void ProcSeq::init ()
{
    // make masks of input and output pins so we know what words to send/receive on i2c busses
    setmpinmask (boardipinmask, procseq_impins);
    setmpinmask (boardopinmask, procseq_ompins);
    mcpsetdir ();
}

// fill all inputs except clock, reset, with random values
void ProcSeq::genrand ()
{
    brkrqst (randbits (1));
    cycle3  (randbits (1));
    intinh  (randbits (1));
    intrqst (randbits (1));

    // change opcode at TP1 of FETCH
    if (clock () && tp1 () && (majst () == 1)) {
        ireg (randbits (3));
    }

    // change MBUF at TP1 and TP2 of any cycle
    if (clock () && (tp1 () || tp2 ())) {
        mbuf (randbits (9));
    }

    // switch action when timer runs out
    if (-- switchtimer < 0) {
        switch (switchstate) {

            // no button currently pressed
            // fiddle the step switches, possibly halting processor
            // if not running, maybe press a button to start the processor
            case SS_NONE: {

                // maybe flip the step switches
                // lean heavily on letting the processor run
                swsinst (randbits (6) == 0);
                swsstep (randbits (6) == 0);

                // if halted, press or release a button
                // lean on cont switch to resume processing
                if (! run ()) {
                    switch (randbits (3)) {
                        case 1: {
                            switchstate = SS_DEPOS;
                            swdepos (1);
                            break;
                        }
                        case 2: {
                            switchstate = SS_EXAM;
                            swexam (1);
                            break;
                        }
                        case 3: {
                            switchstate = SS_LDAD;
                            swldad (1);
                            break;
                        }
                        case 4: {
                            switchstate = SS_START;
                            swstart (1);
                            break;
                        }
                        default: {
                            switchstate = SS_CONT;
                            swcont (1);
                            break;
                        }
                    }
                }
                break;
            }

            // some button already pressed, release it
            case SS_CONT: {
                switchstate = SS_NONE;
                swcont (0);
                break;
            }
            case SS_DEPOS: {
                switchstate = SS_NONE;
                swdepos (0);
                break;
            }
            case SS_EXAM: {
                switchstate = SS_NONE;
                swexam (0);
                break;
            }
            case SS_LDAD: {
                switchstate = SS_NONE;
                swldad (0);
                break;
            }
            case SS_START: {
                switchstate = SS_NONE;
                swstart (0);
                break;
            }

            default: abort ();
        }

        // reset timer for 32..63 50nS cycles
        // counts are 50nS each (cuz we are called twice per 100nS clock)
        switchtimer = 64 + randbits (6);
    }
}

// send values to circuit board then retrieve the results
void ProcSeq::update ()
{
    int mp;
    for (int const *impins = procseq_impins; (mp = *impins) != 0; impins ++) {
        CData *v = vprseqbits[mp];
        setmpin (mp, *v);
    }

    // send bits to circuit board
    mcpsend ();

    // send random bits to verilog then compute reply
    // clock it through 500nS of chips-varns.v delays
    for (int i = 0; i < 100; i ++) {
        feedback ();
        vprseq.eval ();
        vprseq.zclock = 1;
        feedback ();
        vprseq.eval ();
        vprseq.zclock = 0;
    }

    // receive bits from circuit board
    mcprecv ();
}

// feed tristate outputs back to the inputs
void ProcSeq::feedback ()
{
    vprseq._BRKGNTO = vprseq._BRKGNTO_o;
    vprseq._BUSINI  = vprseq._BUSINI_o;
    vprseq._ION     = vprseq._ION_o;
    vprseq._IOP     = vprseq._IOP_o;
    vprseq._MAJST_0 = vprseq._MAJST_0_o;
    vprseq._MAJST_1 = vprseq._MAJST_1_o;
    vprseq._MAJST_2 = vprseq._MAJST_2_o;
    vprseq._MAJST_3 = vprseq._MAJST_3_o;
    vprseq._PAUSE   = vprseq._PAUSE_o;
    vprseq._RUN     = vprseq._RUN_o;
    vprseq._TP1     = vprseq._TP1_o;
    vprseq._TP2     = vprseq._TP2_o;
    vprseq._TP3     = vprseq._TP3_o;
    vprseq._TP4     = vprseq._TP4_o;
    vprseq._TS1     = vprseq._TS1_o;
    vprseq._TS2     = vprseq._TS2_o;
    vprseq._TS3     = vprseq._TS3_o;
    vprseq._TS4     = vprseq._TS4_o;
}

void ProcSeq::printsent ()
{
    printf ("raspi->board: brkrqst=%o clock=%o cycle3=%o intinh=%o intrqst=%o ireg=%o mbuf=%03o reset=%o\n"
            "              swcont=%o swdepos=%o swexam=%o swldad=%o swsinst=%o swsstep=%o swstart=%o\n",
        getmpin  (mp__BRKRQST) ^ 1,
        getmpin  (mp__CLOCK)   ^ 1,
        getmpin  (mp__CYCLE3)  ^ 1,
        getmpin  (mp__INTINH)  ^ 1,
        getmpin  (mp__INTRQST) ^ 1,
        getmpins (mps__IREG)   ^ 7,
       (getmpins (mps__MBUF)   ^ 0777) & 0777,
        getmpin  (mp__RESET)   ^ 1,
        getmpin  (mp__SWCONT)  ^ 1,
        getmpin  (mp__SWDEPOS) ^ 1,
        getmpin  (mp__SWEXAM)  ^ 1,
        getmpin  (mp__SWLDAD)  ^ 1,
        getmpin  (mp__SWSINST) ^ 1,
        getmpin  (mp__SWSSTEP) ^ 1,
        getmpin  (mp__SWSTART) ^ 1);
}

void ProcSeq::printrcvd ()
{
    printf ("board->raspi: brkgnto=%o busini=%o ion=%o iop=%o majst=%X pause=%o run=%o tp=%o%o%o%o ts=%o%o%o%o memacsw=%o nxtms=%X\n",
        getmpin  (mp__BRKGNTO) ^ 1,
        getmpin  (mp__BUSINI)  ^ 1,
        getmpin  (mp__ION)     ^ 1,
        getmpin  (mp__IOP)     ^ 1,
        getmpins (mps__MAJST)  ^ 15,
        getmpin  (mp__PAUSE)   ^ 1,
        getmpin  (mp__RUN)     ^ 1,
        getmpin (mp__TP1) ^ 1, getmpin (mp__TP2) ^ 1, getmpin (mp__TP3) ^ 1, getmpin (mp__TP4) ^ 1,
        getmpin (mp__TS1) ^ 1, getmpin (mp__TS2) ^ 1, getmpin (mp__TS3) ^ 1, getmpin (mp__TS4) ^ 1,
        getmpin  (mp_memacsw),
        getmpins (mps_nxtms));
}

// compare to make sure the replies are the same
bool ProcSeq::verify ()
{
    bool error = false;
    int mp;
    for (int const *ompins = procseq_ompins; (mp = *ompins) != 0; ompins ++) {
        CData *v = vprseqbits[mp];  // get pointer to verilator struct
        bool vsb = *v;              // get verilated pin value
        bool vis = getmpin (mp);    // get physical pin from mcp23017
        if (vis != vsb) {
            int cp = mptocp[mp];    // error, get connector pin
            int jack = (cp >> 6) + 1;
            int jpin = cp & 63;
            fprintf (stderr, "pin %-8s J%dP%02d is %d, should be %d\n", vprseqnames[mp], jack, jpin, vis, vsb);
            error = true;
        }
    }
    return ! error;
}

// print state of all flipflops according to verilog
void ProcSeq::puqueffs ()
{
    printf ("E25A MAJST_3  Q(5)=%o _Q(6)=%o\n", vprseq.procseq__DOT__majst_3, vprseq.procseq__DOT___majst_3);
    printf ("E25B MAJST_2  Q(9)=%o _Q(8)=-\n",  vprseq.procseq__DOT__majst_2);
    printf ("E34A MAJST_1  Q(5)=%o _Q(6)=-\n",  vprseq.procseq__DOT__majst_1);
    printf ("E34B MAJST_0  Q(9)=%o _Q(8)=-\n",  vprseq.procseq__DOT__majst_0);
    printf ("E47  TSCT 3(11)=%o 2(12)=%o 1(13)=%o 0(14)=%o\n", vprseq.procseq__DOT__tsct_3, vprseq.procseq__DOT__tsct_2, vprseq.procseq__DOT__tsct_1, vprseq.procseq__DOT__tsct_0);
    printf ("E53A IOP      Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__iop, vprseq.procseq__DOT___iop);
    printf ("E53B TS4     Q(10)=%o _Q(9)=%o\n", vprseq.procseq__DOT__ts4, vprseq.procseq__DOT___ts4);
    printf ("E54A TP3      Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__tp3, vprseq.procseq__DOT___tp3);
    printf ("E54B TP4      Q(9)=%o _Q(8)=%o\n", vprseq.procseq__DOT__tp4, vprseq.procseq__DOT___tp4);
    printf ("E56A TS2      Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__ts2, vprseq.procseq__DOT___ts2);
    printf ("E56B TS3     Q(10)=%o _Q(9)=%o\n", vprseq.procseq__DOT__ts3, vprseq.procseq__DOT___ts3);
    printf ("E63A HGNT     Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__hgnt, vprseq.procseq__DOT__run);
    printf ("E63B TS1     Q(10)=%o _Q(9)=%o\n", vprseq.procseq__DOT__ts1, vprseq.procseq__DOT___ts1);
    printf ("E65A TP1      Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__tp1, vprseq.procseq__DOT___tp1);
    printf ("E65B TP2      Q(9)=%o _Q(8)=%o\n", vprseq.procseq__DOT__tp2, vprseq.procseq__DOT___tp2);
    printf ("E67A INTDEL   Q(6)=%o _Q(7)=-\n",  vprseq.procseq__DOT__intdelayed);
    printf ("E67B ION     Q(10)=%o _Q(9)=%o\n", vprseq.procseq__DOT__ion, vprseq.procseq__DOT___ion);
    printf ("E75A INTGRNT  Q(5)=%o=E66A-2\n",   vprseq.procseq__DOT__intgrnt);
    printf ("E75B BRKGRNT  Q(9)=- _Q(8)=%o\n",  vprseq.procseq__DOT___brkgrnt);
    printf ("E76A HREQ     Q(6)=%o _Q(7)=%o\n", vprseq.procseq__DOT__hreq, vprseq.procseq__DOT___hreq);
    printf ("E76B         Q(10)=- _Q(9)=%o\n",  vprseq.procseq__DOT___hreq_k);
    printf ("E77A SYNPAUSE Q(5)=- _Q(6)=%o\n",  vprseq.procseq__DOT___synpause);
}



///////////////////////////////////////////////////////////
//  signals received by the board (inputs to the board)  //
///////////////////////////////////////////////////////////

void ProcSeq::brkrqst (bool v) { vprseq._BRKRQST = ! v; }
void ProcSeq::clock   (bool v) { vprseq._CLOCK   = ! v; }
void ProcSeq::cycle3  (bool v) { vprseq._CYCLE3  = ! v; }
void ProcSeq::intinh  (bool v) { vprseq._INTINH  = ! v; }
void ProcSeq::intrqst (bool v) { vprseq._INTRQST = ! v; }
void ProcSeq::ireg    (uint8_t v)
{
    vprseq._IREG_9  = (~ v >> 0) & 1;
    vprseq._IREG_10 = (~ v >> 1) & 1;
    vprseq._IREG_11 = (~ v >> 2) & 1;
}
void ProcSeq::mbuf    (uint16_t v)
{
    vprseq._MBUF_0  = (~ v >> 0) & 1;
    vprseq._MBUF_1  = (~ v >> 1) & 1;
    vprseq._MBUF_2  = (~ v >> 2) & 1;
    vprseq._MBUF_3  = (~ v >> 3) & 1;
    vprseq._MBUF_4  = (~ v >> 4) & 1;
    vprseq._MBUF_5  = (~ v >> 5) & 1;
    vprseq._MBUF_6  = (~ v >> 6) & 1;
    vprseq._MBUF_7  = (~ v >> 7) & 1;
    vprseq._MBUF_8  = (~ v >> 8) & 1;
}
void ProcSeq::reset   (bool v) { vprseq._RESET   = ! v; }
void ProcSeq::swcont  (bool v) { vprseq._SWCONT  = ! v; }
void ProcSeq::swdepos (bool v) { vprseq._SWDEPOS = ! v; }
void ProcSeq::swexam  (bool v) { vprseq._SWEXAM  = ! v; }
void ProcSeq::swldad  (bool v) { vprseq._SWLDAD  = ! v; }
void ProcSeq::swsinst (bool v) { vprseq._SWSINST = ! v; }
void ProcSeq::swsstep (bool v) { vprseq._SWSSTEP = ! v; }
void ProcSeq::swstart (bool v) { vprseq._SWSTART = ! v; }

bool ProcSeq::clock   () { return ! vprseq._CLOCK;   }
bool ProcSeq::intrqst () { return ! vprseq._INTRQST; }
uint8_t  ProcSeq::ireg ()
{
    return
        (((uint8_t) vprseq._IREG_9  << 0) |
         ((uint8_t) vprseq._IREG_10 << 1) |
         ((uint8_t) vprseq._IREG_11 << 2)) ^ 7;
}
uint16_t ProcSeq::mbuf ()
{
    return
        (((uint16_t) vprseq._MBUF_0 << 0) |
         ((uint16_t) vprseq._MBUF_1 << 1) |
         ((uint16_t) vprseq._MBUF_2 << 2) |
         ((uint16_t) vprseq._MBUF_3 << 3) |
         ((uint16_t) vprseq._MBUF_4 << 4) |
         ((uint16_t) vprseq._MBUF_5 << 5) |
         ((uint16_t) vprseq._MBUF_6 << 6) |
         ((uint16_t) vprseq._MBUF_7 << 7) |
         ((uint16_t) vprseq._MBUF_8 << 8)) ^ 0777;
}

//////////////////////////////////////////////////////////
//  signals sent by the board (outputs from the board)  //
//////////////////////////////////////////////////////////

bool     ProcSeq::brkgnto () { return ! vprseq._BRKGNTO; }
bool     ProcSeq::busini  () { return ! vprseq._BUSINI;  }
bool     ProcSeq::ion     () { return ! vprseq._ION;     }
bool     ProcSeq::iop     () { return ! vprseq._IOP;     }
uint8_t  ProcSeq::majst ()
{
    return
        (((uint8_t) vprseq._MAJST_0 << 0) |
         ((uint8_t) vprseq._MAJST_1 << 1) |
         ((uint8_t) vprseq._MAJST_2 << 2) |
         ((uint8_t) vprseq._MAJST_3 << 3)) ^ 15;
}
bool     ProcSeq::pause   () { return ! vprseq._PAUSE;  }
bool     ProcSeq::run     () { return ! vprseq._RUN;    }
bool     ProcSeq::tp1     () { return ! vprseq._TP1;    }
bool     ProcSeq::tp2     () { return ! vprseq._TP2;    }
bool     ProcSeq::tp3     () { return ! vprseq._TP3;    }
bool     ProcSeq::tp4     () { return ! vprseq._TP4;    }
bool     ProcSeq::ts1     () { return ! vprseq._TS1;    }
bool     ProcSeq::ts2     () { return ! vprseq._TS2;    }
bool     ProcSeq::ts3     () { return ! vprseq._TS3;    }
bool     ProcSeq::ts4     () { return ! vprseq._TS4;    }
bool     ProcSeq::memacsw () { return   vprseq.memacsw; }
uint8_t  ProcSeq::nxtms ()
{
    return
         ((uint8_t) vprseq.nxtms_0 << 0) |
         ((uint8_t) vprseq.nxtms_1 << 1) |
         ((uint8_t) vprseq.nxtms_2 << 2) |
         ((uint8_t) vprseq.nxtms_3 << 3);
}
