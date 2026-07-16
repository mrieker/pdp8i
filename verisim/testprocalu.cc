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

// test physical procalu board
// runs on raspi plugged into tester board with physical procalu board plugged in

// sends random numbers to the board then compares with verilator equivalent

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "testlib.h"
#include "Vprocalu.h"

#define MAPMPIN(mp) do { vpralubits[mp_##mp] = &vpralu.mp; vpralunames[mp_##mp] = #mp; } while (0)

static int const procalu_impins[] = {
    mp__ACCLEAR, mp__ACUM_0, mp__ACUM_1, mp__ACUM_2, mp__ACUM_3, mp__ACUM_4, mp__ACUM_5, mp__ACUM_6, mp__ACUM_7, mp__ACUM_8, mp__ACUM_9,
    mp__ACUM_10, mp__ACUM_11, mp__BRKWRM, mp__CAINC, mp__CYCLE3, mp__INBUS_0, mp__INBUS_1, mp__INBUS_2, mp__INBUS_3, mp__INBUS_4, 
    mp__INBUS_5, mp__INBUS_6, mp__INBUS_7, mp__INBUS_8, mp__INBUS_9, mp__INBUS_10, mp__INBUS_11, mp__IOP, mp__IREG_9, mp__IREG_10,
    mp__IREG_11, mp__LINK, mp__MADR_0, mp__MADR_1, mp__MADR_2, mp__MADR_3, mp__MADR_4, mp__MADR_5, mp__MADR_6, mp__MADR_7, mp__MADR_8,
    mp__MADR_9, mp__MADR_10, mp__MADR_11, mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3, mp__MBUF_0,mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, 
    mp__MBUF_4, mp__MBUF_5, mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, mp__MBUF_9, mp__MBUF_10, mp__MBUF_11, mp__PCTR_0, mp__PCTR_1, mp__PCTR_2, 
    mp__PCTR_3, mp__PCTR_4, mp__PCTR_5, mp__PCTR_6, mp__PCTR_7, mp__PCTR_8, mp__PCTR_9, mp__PCTR_10, mp__PCTR_11, mp__SWCONT, mp__SWDEPOS, 
    mp__SWEXAM, mp__SWLDAD, mp__SWSTART, mp__TS1, mp__TS2, mp__TS3, mp__TS4, mp_nxtms_0, mp_nxtms_1, mp_nxtms_2, mp_nxtms_3, 0 };

static int const procalu_ompins[] = {
    mp__READSR, mp_aluq_0, mp_aluq_1, mp_aluq_2, mp_aluq_3, mp_aluq_4, mp_aluq_5, mp_aluq_6, mp_aluq_7, mp_aluq_8, mp_aluq_9,
    mp_aluq_10, mp_aluq_11, mp_cout, 0 };

static int const mps_nxtms[] = { mp_nxtms_3, mp_nxtms_2, mp_nxtms_1, mp_nxtms_0, 0 };
static int const mps_aluq[] = {
    mp_aluq_11, mp_aluq_10, mp_aluq_9, mp_aluq_8,
    mp_aluq_7,  mp_aluq_6,  mp_aluq_5, mp_aluq_4,
    mp_aluq_3,  mp_aluq_2,  mp_aluq_1, mp_aluq_0,
    0 };

struct ProcALU {
    Vprocalu vpralu;            // verilated circuit board
    CData *vpralubits[256];     // pointers to vpralu elements, indexed by mpin
    char const *vpralunames[256];

    // sendables
    void acclear (bool v);
    void brkwrm  (bool v);
    void cainc   (bool v);
    void cycle3  (bool v);
    void iop     (bool v);
    void link    (bool v);
    void acum    (uint16_t v);
    void inbus   (uint16_t v);
    void ireg    (uint16_t v);
    void madr    (uint16_t v);
    void majst   (uint16_t v);
    void mbuf    (uint16_t v);
    void pctr    (uint16_t v);
    void swtch   (uint16_t v);
    void timst   (uint16_t v);
    void nxtms   (uint16_t v);

    // receiveables
    bool     readsr ();
    bool     cout   ();
    uint16_t aluq   ();

    ProcALU ();
    void init ();
    void genrand ();
    void update ();
    void printsent ();
    void printrcvd ();
    void printpins ();
    bool verify ();
};

static volatile bool ctrlcflag;
static ProcALU procalu;

static void sighand (int signum);

int main ()
{
    setlinebuf (stdout);

    signal (SIGINT, sighand);

    procalu.init ();

#if 000
    for (int j = 4; j <= 4; j ++) {
        for (int p = 2; p <= 35; p ++) {
            int cp = (j - 1) * 64 + p;      // get connector pin
            int mp = cptomp[cp];            // get mcp23017 pin
            for (int const *impins = procalu_impins; *impins != 0; impins ++) {
                if (*impins == mp) {        // see if input to the board
                    ctrlcflag = false;
                    do {
                        for (int v = 0; v < 2; v ++) {
                            printf ("J%d P%02d < %d  %s\n", j, p, v, vpralunames[mp]);
                            setmpin (mp, v);
                            mcpsend ();
                            sleep (1);
                        }
                    } while (! ctrlcflag);
                }
            }
        }
    }
#endif

#if 000
    // alua = acum
    //  _asel = 3
    //  azero = 0
    //  comac = 0
    // alub = mbuf
    //  _bsel = 1
    //  bzero = 0
    // aluq = alua + alub
    //  qsel = 2          FF | PP2
    //  PP2 = 1 = TS3 & MSEXEC & IRTAD

    while (true) {
        procalu.acum  (01234);
        procalu.mbuf  (04321);
        procalu.ireg  (01000);  // TAD
        procalu.majst (3);      // MS_EXEC
        procalu.timst (3);      // TS3

        procalu.update ();
        procalu.printsent ();
        procalu.printrcvd ();
        procalu.verify ();

        char temp[8];
        if (read (0, temp, sizeof temp) <= 0) break;
    }
#endif

    uint32_t ntest = 0;
    while (! ctrlcflag) {
        printf ("\nntest=%10u\n", ++ ntest);

        procalu.genrand ();
        procalu.update ();
        procalu.printsent ();
        procalu.printrcvd ();
        if (! procalu.verify ()) {
            char temp[8];
            if (read (0, temp, sizeof temp) <= 0) break;
        }
    }

    return 0;
}

/***
static void dumppins (int const *pins)
{
    for (int pin; (pin = *pins) != 0; pins ++) {
        int bus  = (pin >> 9) - 1;
        int chip = (pin >> 6) & 7;
        int bit  = pin & 15;
        char const *name = pinnames[bus*128+chip*16+bit];
        for (Subst const *s = procalu_subst; s->num != 0; s ++) {
            if (s->num == pin) name = s->str;
        }
        printf ("%14s=%o", name, (mcppins[bus*8+chip] >> bit) & 1);
    }
}
***/

static void sighand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}


ProcALU::ProcALU ()
{
    vpralu.VCC = 1;
    vpralu.GND = 0;

    memset (vpralubits,  0, sizeof vpralubits);
    memset (vpralunames, 0, sizeof vpralunames);

    MAPMPIN (_ACCLEAR);
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
    MAPMPIN (_BRKWRM);
    MAPMPIN (_CAINC);
    MAPMPIN (_CYCLE3);
    MAPMPIN (_INBUS_0);
    MAPMPIN (_INBUS_1);
    MAPMPIN (_INBUS_2);
    MAPMPIN (_INBUS_3);
    MAPMPIN (_INBUS_4);
    MAPMPIN (_INBUS_5);
    MAPMPIN (_INBUS_6);
    MAPMPIN (_INBUS_7);
    MAPMPIN (_INBUS_8);
    MAPMPIN (_INBUS_9);
    MAPMPIN (_INBUS_10);
    MAPMPIN (_INBUS_11);
    MAPMPIN (_IOP);
    MAPMPIN (_IREG_9);
    MAPMPIN (_IREG_10);
    MAPMPIN (_IREG_11);
    MAPMPIN (_LINK);
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
    MAPMPIN (_MAJST_0);
    MAPMPIN (_MAJST_1);
    MAPMPIN (_MAJST_2);
    MAPMPIN (_MAJST_3);
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
    MAPMPIN (_SWCONT);
    MAPMPIN (_SWDEPOS);
    MAPMPIN (_SWEXAM);
    MAPMPIN (_SWLDAD);
    MAPMPIN (_SWSTART);
    MAPMPIN (_TS1);
    MAPMPIN (_TS2);
    MAPMPIN (_TS3);
    MAPMPIN (_TS4);
    MAPMPIN (nxtms_0);
    MAPMPIN (nxtms_1);
    MAPMPIN (nxtms_2);
    MAPMPIN (nxtms_3);

    MAPMPIN (_READSR);
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

    acclear (0);
    brkwrm  (0);
    cainc   (0);
    cycle3  (0);
    iop     (0);
    link    (0);
    acum    (0);
    inbus   (0);
    ireg    (0);
    madr    (0);
    majst   (0);
    mbuf    (0);
    pctr    (0);
    swtch   (0);
    timst   (0);
    nxtms   (0);
}

void ProcALU::init ()
{
    // make masks of input and output pins so we know what words to send/receive on i2c busses
    fillmaskarray (boardipinmask, procalu_impins);
    fillmaskarray (boardopinmask, procalu_ompins);
    mcpsetdir ();
}

// fill all inputs with random values
void ProcALU::genrand ()
{
    uint32_t rands = randbits (32);
    majst   (rands % 9 + 1); rands /= 9;
    swtch   (rands % 64); rands /= 64;
    timst   (rands % 8); rands /= 8;
    nxtms   (rands % 9 + 1); rands /= 9;

    acclear (randbits (1));
    brkwrm  (randbits (1));
    cainc   (randbits (1));
    cycle3  (randbits (1));
    iop     (randbits (1));
    link    (randbits (1));

    acum    (randbits (12));
    inbus   (randbits (12));
    ireg    (randbits (3) << 9);
    madr    (randbits (12));
    mbuf    (randbits (12));
    pctr    (randbits (12));
}

// send values to circuit board then retrieve the results
void ProcALU::update ()
{
    int mp;
    for (int const *impins = procalu_impins; (mp = *impins) != 0; impins ++) {
        CData *v = vpralubits[mp];
        setmpin (mp, *v);
    }

    // send bits to circuit board
    mcpsend ();

    // send random bits to verilog then compute reply
    // clock it through 500nS of chips-varns.v delays
    for (int i = 0; i < 100; i ++) {
        vpralu._READSR = vpralu._READSR_o;
        vpralu.eval ();
        vpralu.zclock = 1;
        vpralu._READSR = vpralu._READSR_o;
        vpralu.eval ();
        vpralu.zclock = 0;
    }

    // receive bits from circuit board
    mcprecv ();
}

void ProcALU::printsent ()
{
    printf ("raspi->board: acclear=%o acum=%04o brkwrm=%o cainc=%o cycle3=%o inbus=%04o iop=%o ireg=%o link=%o madr=%04o majst=%x\n"
            "              mbuf=%04o pctr=%04o swcont=%o swdepos=%o swexam=%o swldad=%o swstart=%o ts=%o%o%o%o nxtms=%x\n",
        getmpin  (mp__ACCLEAR) ^ 1,
        getmpins (mps__ACUM)   ^ 07777,
        getmpin  (mp__BRKWRM)  ^ 1,
        getmpin  (mp__CAINC)   ^ 1,
        getmpin  (mp__CYCLE3)  ^ 1,
        getmpins (mps__INBUS)  ^ 07777,
        getmpin  (mp__IOP)     ^ 1,
        getmpins (mps__IREG)   ^ 7,
        getmpin  (mp__LINK)    ^ 1,
        getmpins (mps__MADR)   ^ 07777,
        getmpins (mps__MAJST)  ^ 15,
        getmpins (mps__MBUF)   ^ 07777,
        getmpins (mps__PCTR)   ^ 07777,
        getmpin  (mp__SWCONT)  ^ 1,
        getmpin  (mp__SWDEPOS) ^ 1,
        getmpin  (mp__SWEXAM)  ^ 1,
        getmpin  (mp__SWLDAD)  ^ 1,
        getmpin  (mp__SWSTART) ^ 1,
        getmpin  (mp__TS1)     ^ 1,
        getmpin  (mp__TS2)     ^ 1,
        getmpin  (mp__TS3)     ^ 1,
        getmpin  (mp__TS4)     ^ 1,
        getmpins (mps_nxtms));
}

void ProcALU::printrcvd ()
{
    printf ("board->raspi: readsr=%o aluq=%04o cout=%o\n",
        getmpin  (mp__READSR)  ^ 1,
        getmpins (mps_aluq),
        getmpin  (mp_cout));
}

void ProcALU::printpins ()
{
    for (int j = 1; j <= 4; j ++) {
        for (int p = 1; p <= 36; p ++) {
/***
            int i = ????
            if (pinnames[i] == NULL) printf ("J%d P%d\n", j, p);
            else {
                bool is = ????;
                bool sb = ????;
                if (is == sb) printf ("J%d P%d is %o       %s\n", j, p, is, pinnames[i]);
                    else printf ("J%d P%d is %o sb %o  %s\n", j, p, is, sb, pinnames[i]);
            }
***/
        }
    }
}

// compare to make sure the replies are the same
bool ProcALU::verify ()
{
    bool error = false;
    int mp;
    for (int const *ompins = procalu_ompins; (mp = *ompins) != 0; ompins ++) {
        CData *v = vpralubits[mp];  // get pointer to verilator struct
        bool vsb = *v;              // get verilated pin value
        bool vis = getmpin (mp);    // get physical pin from mcp23017
        if (vis != vsb) {
            int cp = mptocp[mp];    // error, get connector pin
            int jack = (cp >> 6) + 1;
            int jpin = cp & 63;
            fprintf (stderr, "pin %-8s J%dP%02d is %d, should be %d\n", vpralunames[mp], jack, jpin, vis, vsb);
            error = true;
        }
    }
    return ! error;
}



void ProcALU::acclear (bool v) { vpralu._ACCLEAR = ! v; }
void ProcALU::brkwrm  (bool v) { vpralu._BRKWRM  = ! v; }
void ProcALU::cainc   (bool v) { vpralu._CAINC   = ! v; }
void ProcALU::cycle3  (bool v) { vpralu._CYCLE3  = ! v; }
void ProcALU::iop     (bool v) { vpralu._IOP     = ! v; }
void ProcALU::link    (bool v) { vpralu._LINK    = ! v; }
void ProcALU::acum    (uint16_t v)
{
    vpralu._ACUM_0  = (~ v >>  0) & 1;
    vpralu._ACUM_1  = (~ v >>  1) & 1;
    vpralu._ACUM_2  = (~ v >>  2) & 1;
    vpralu._ACUM_3  = (~ v >>  3) & 1;
    vpralu._ACUM_4  = (~ v >>  4) & 1;
    vpralu._ACUM_5  = (~ v >>  5) & 1;
    vpralu._ACUM_6  = (~ v >>  6) & 1;
    vpralu._ACUM_7  = (~ v >>  7) & 1;
    vpralu._ACUM_8  = (~ v >>  8) & 1;
    vpralu._ACUM_9  = (~ v >>  9) & 1;
    vpralu._ACUM_10 = (~ v >> 10) & 1;
    vpralu._ACUM_11 = (~ v >> 11) & 1;
}
void ProcALU::inbus   (uint16_t v)
{
    vpralu._INBUS_0  = (~ v >>  0) & 1;
    vpralu._INBUS_1  = (~ v >>  1) & 1;
    vpralu._INBUS_2  = (~ v >>  2) & 1;
    vpralu._INBUS_3  = (~ v >>  3) & 1;
    vpralu._INBUS_4  = (~ v >>  4) & 1;
    vpralu._INBUS_5  = (~ v >>  5) & 1;
    vpralu._INBUS_6  = (~ v >>  6) & 1;
    vpralu._INBUS_7  = (~ v >>  7) & 1;
    vpralu._INBUS_8  = (~ v >>  8) & 1;
    vpralu._INBUS_9  = (~ v >>  9) & 1;
    vpralu._INBUS_10 = (~ v >> 10) & 1;
    vpralu._INBUS_11 = (~ v >> 11) & 1;
}
void ProcALU::ireg    (uint16_t v)
{
    vpralu._IREG_9  = (~ v >>  9) & 1;
    vpralu._IREG_10 = (~ v >> 10) & 1;
    vpralu._IREG_11 = (~ v >> 11) & 1;
}
void ProcALU::madr    (uint16_t v)
{
    vpralu._MADR_0  = (~ v >>  0) & 1;
    vpralu._MADR_1  = (~ v >>  1) & 1;
    vpralu._MADR_2  = (~ v >>  2) & 1;
    vpralu._MADR_3  = (~ v >>  3) & 1;
    vpralu._MADR_4  = (~ v >>  4) & 1;
    vpralu._MADR_5  = (~ v >>  5) & 1;
    vpralu._MADR_6  = (~ v >>  6) & 1;
    vpralu._MADR_7  = (~ v >>  7) & 1;
    vpralu._MADR_8  = (~ v >>  8) & 1;
    vpralu._MADR_9  = (~ v >>  9) & 1;
    vpralu._MADR_10 = (~ v >> 10) & 1;
    vpralu._MADR_11 = (~ v >> 11) & 1;
}
void ProcALU::majst   (uint16_t v)
{
    vpralu._MAJST_0 = (~ v >>  0) & 1;
    vpralu._MAJST_1 = (~ v >>  1) & 1;
    vpralu._MAJST_2 = (~ v >>  2) & 1;
    vpralu._MAJST_3 = (~ v >>  3) & 1;
}
void ProcALU::mbuf    (uint16_t v)
{
    vpralu._MBUF_0  = (~ v >>  0) & 1;
    vpralu._MBUF_1  = (~ v >>  1) & 1;
    vpralu._MBUF_2  = (~ v >>  2) & 1;
    vpralu._MBUF_3  = (~ v >>  3) & 1;
    vpralu._MBUF_4  = (~ v >>  4) & 1;
    vpralu._MBUF_5  = (~ v >>  5) & 1;
    vpralu._MBUF_6  = (~ v >>  6) & 1;
    vpralu._MBUF_7  = (~ v >>  7) & 1;
    vpralu._MBUF_8  = (~ v >>  8) & 1;
    vpralu._MBUF_9  = (~ v >>  9) & 1;
    vpralu._MBUF_10 = (~ v >> 10) & 1;
    vpralu._MBUF_11 = (~ v >> 11) & 1;
}
void ProcALU::pctr    (uint16_t v)
{
    vpralu._PCTR_0  = (~ v >>  0) & 1;
    vpralu._PCTR_1  = (~ v >>  1) & 1;
    vpralu._PCTR_2  = (~ v >>  2) & 1;
    vpralu._PCTR_3  = (~ v >>  3) & 1;
    vpralu._PCTR_4  = (~ v >>  4) & 1;
    vpralu._PCTR_5  = (~ v >>  5) & 1;
    vpralu._PCTR_6  = (~ v >>  6) & 1;
    vpralu._PCTR_7  = (~ v >>  7) & 1;
    vpralu._PCTR_8  = (~ v >>  8) & 1;
    vpralu._PCTR_9  = (~ v >>  9) & 1;
    vpralu._PCTR_10 = (~ v >> 10) & 1;
    vpralu._PCTR_11 = (~ v >> 11) & 1;
}
void ProcALU::swtch   (uint16_t v)
{
    vpralu._SWCONT  = v != 11;
    vpralu._SWDEPOS = v != 22;
    vpralu._SWEXAM  = v != 33;
    vpralu._SWLDAD  = v != 44;
    vpralu._SWSTART = v != 55;
}
void ProcALU::timst   (uint16_t v)
{
    vpralu._TS1 = v != 1;
    vpralu._TS2 = v != 2;
    vpralu._TS3 = v != 3;
    vpralu._TS4 = v != 4;
}
void ProcALU::nxtms   (uint16_t v)
{
    vpralu.nxtms_0 = (v >>  0) & 1;
    vpralu.nxtms_1 = (v >>  1) & 1;
    vpralu.nxtms_2 = (v >>  2) & 1;
    vpralu.nxtms_3 = (v >>  3) & 1;
}

bool     ProcALU::readsr () { return ! vpralu._READSR; }
bool     ProcALU::cout   () { return   vpralu.cout;    }
uint16_t ProcALU::aluq   ()
{
    return
        ((uint16_t) vpralu.aluq_0  <<  0) |
        ((uint16_t) vpralu.aluq_1  <<  1) |
        ((uint16_t) vpralu.aluq_2  <<  2) |
        ((uint16_t) vpralu.aluq_3  <<  3) |
        ((uint16_t) vpralu.aluq_4  <<  4) |
        ((uint16_t) vpralu.aluq_5  <<  5) |
        ((uint16_t) vpralu.aluq_6  <<  6) |
        ((uint16_t) vpralu.aluq_7  <<  7) |
        ((uint16_t) vpralu.aluq_8  <<  8) |
        ((uint16_t) vpralu.aluq_9  <<  9) |
        ((uint16_t) vpralu.aluq_10 << 10) |
        ((uint16_t) vpralu.aluq_11 << 11);
}
