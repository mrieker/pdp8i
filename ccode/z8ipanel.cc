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

// access pdp-8/i front panel via backplane piggy-back board connected to the Zynq
// see ./z8ipanel -? for options

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <tcl.h>
#include <unistd.h>

#include "assemble.h"
#include "cmd_pin.h"
#include "disassemble.h"
#include "i2czlib.h"
#include "readprompt.h"
#include "tclmain.h"
#include "z8idefs.h"
#include "z8iutil.h"

struct Switch {
    struct Switches *sws;
    char const *name;
    int nbits;
    void *ovrptr, *valptr;

    uint32_t get () const;
    void rel () const;
    bool set (uint32_t val) const;
};

struct Switches {
    Switches ();
    ~Switches ();

    Switch const *list;
    bool mademods;

private:
    Z8IPanel pads;
};

// internal TCL commands
static Tcl_ObjCmdProc cmd_assemop;
static Tcl_ObjCmdProc cmd_disasop;
static Tcl_ObjCmdProc cmd_getlb;
static Tcl_ObjCmdProc cmd_getsw;
static Tcl_ObjCmdProc cmd_readchar;
static Tcl_ObjCmdProc cmd_relsw;
static Tcl_ObjCmdProc cmd_setsw;

static TclFunDef const fundefs[] = {
    { cmd_assemop,    "assemop",    "assemble instruction" },
    { cmd_disasop,    "disasop",    "disassemble instruction" },
    { cmd_getlb,      "getlb",      "get light bulb value" },
    { cmd_getsw,      "getsw",      "get switch value" },
    { CMD_PIN },
    { cmd_readchar,   "readchar",   "read character with timeout" },
    { cmd_relsw,      "relsw",      "release control of switch" },
    { cmd_setsw,      "setsw",      "set switch value" },
    { NULL, NULL, NULL }
};

static char const *const msnames[] = { MS_NAMES };

static I2CZLib *padlib;

static int showstatus (int argc, char **argv);



int main (int argc, char **argv)
{
    if ((argc >= 2) && (strcasecmp (argv[1], "-status") == 0)) {
        return showstatus (argc - 1, argv + 1);
    }

    setlinebuf (stdout);

    bool imm  = false;
    bool real = false;
    bool sim  = false;
    char const *logname = NULL;
    int tclargs = argc;
    for (int i = 0; ++ i < argc;) {
        if (strcmp (argv[i], "-?") == 0) {
            puts ("");
            puts ("  ./z8ipanel [-imm] [-log <logfile>] [-real | -sim] [<scriptfile.tcl>]");
            puts ("     access pdp-8/i front panel");
            puts ("         -imm : scriptfile arg is immediate command string");
            puts ("         -log : record output to given log file");
            puts ("        -real : use real pdp-8/i (resets processor)");
            puts ("         -sim : simulate the pdp-8/i (resets processor)");
            puts ("     <scriptfile.tcl> : execute script then exit");
            puts ("                 else : read and process commands from stdin");
            puts ("");
            puts ("  ./z8ipanel -status");
            puts ("     display ascii-art front panel");
            puts ("");
            return 0;
        }
        if (strcasecmp (argv[i], "-imm") == 0) {
            imm = true;
            continue;
        }
        if (strcasecmp (argv[i], "-log") == 0) {
            if ((++ i >= argc) || (argv[i][0] == '-')) {
                fprintf (stderr, "missing filename after -log\n");
                return 1;
            }
            logname = argv[i];
            continue;
        }
        if (strcasecmp (argv[i], "-real") == 0) {
            real = true;
            sim  = false;
            continue;
        }
        if (strcasecmp (argv[i], "-sim") == 0) {
            real = false;
            sim  = true;
            continue;
        }
        if (argv[i][0] == '-') {
            fprintf (stderr, "unknown option %s\n", argv[i]);
            return 1;
        }
        tclargs = i;
        break;
    }

    // access lights and switches via i2c
    padlib = new I2CZLib ();

    // process tcl commands
    char const *initargs[2] = { NULL, NULL };
    if (real) initargs[0] = "-real";
    if (sim)  initargs[0] = "-sim";
    return tclmain (fundefs, argv[0], "z8ipanel", logname, getenv ("z8ipanelini"), argc - tclargs, argv + tclargs, false, initargs, imm);
}



// assemble instruciton
//  assemop [address] opcode
static int cmd_assemop (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc > 1) {
        int i = 1;
        char const *stri = Tcl_GetString (objv[i]);
        if (strcasecmp (stri, "help") == 0) {
            puts ("");
            puts ("  assemop [<address>] <opcode>...");
            puts ("   address = integer address of the opcode (for page-relative addresses)");
            puts ("    opcode = opcode string(s)");
            puts ("");
            return TCL_OK;
        }

        char *p;
        uint16_t address = strtoul (stri, &p, 0);
        if ((objc == 2) || (p == stri) || (*p != 0)) address = 0200;
                              else stri = Tcl_GetString (objv[++i]);

        std::string opstr;
        while (true) {
            opstr.append (stri);
            if (++ i >= objc) break;
            opstr.push_back (' ');
            stri = Tcl_GetString (objv[i]);
        }

        uint16_t opcode;
        char *err = assemble (opstr.c_str (), address, &opcode);
        if (err != NULL) {
            Tcl_SetResult (interp, err, (void (*) (char *)) free);
            return TCL_ERROR;
        }
        Tcl_SetObjResult (interp, Tcl_NewIntObj (opcode));
        return TCL_OK;
    }

    Tcl_SetResult (interp, (char *) "bad number of arguments", TCL_STATIC);
    return TCL_ERROR;
}

// disassemble instruciton
//  disasop opcode [address]
static int cmd_disasop (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    int opcode = -1;
    int addr = 0200;

    switch (objc) {
        case 2: {
            char const *opstr = Tcl_GetString (objv[1]);
            if (strcasecmp (opstr, "help") == 0) {
                puts ("");
                puts ("  disasop <opcode> [<address>]");
                puts ("    opcode = integer opcode");
                puts ("   address = integer address of the opcode (for page-relative addresses)");
                puts ("");
                return TCL_OK;
            }
            int rc = Tcl_GetIntFromObj (interp, objv[1], &opcode);
            if (rc != TCL_OK) return rc;
            break;
        }
        case 3: {
            int rc = Tcl_GetIntFromObj (interp, objv[1], &opcode);
            if (rc == TCL_OK) rc = Tcl_GetIntFromObj (interp, objv[2], &addr);
            if (rc != TCL_OK) return rc;
            break;
        }
        default: {
            Tcl_SetResult (interp, (char *) "bad number of arguments", TCL_STATIC);
            return TCL_ERROR;
        }
    }

    std::string str = disassemble (opcode, addr);
    Tcl_SetResult (interp, strdup (str.c_str ()), (void (*) (char *)) free);
    return TCL_OK;
}

// get light bulb
static int cmd_getlb (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts (" getlb <lightbulbname>...");
        puts ("   multi-bit lights:");
        puts ("      ac - accumulator");
        puts ("      df - data field 0..7");
        puts ("      ea - extended address 0..7");
        puts ("      if - instruction field 0..7");
        puts ("      ir - instruction register 0..7");
        puts ("      ma - memory address");
        puts ("      mb - memory buffer");
        puts ("      mq - multiplier quotient");
        puts ("      ms - major state");
        puts ("      pc - program counter");
        puts ("      sc - shift count");
        puts ("   single-bit lights:");
        puts ("     ion - interrupts enabled");
        puts ("    link - link bit");
        puts ("     pau - paused");
        puts ("     run - executing instructions");
        puts ("");
        return TCL_OK;
    }

    Z8IPanel pads;
    padlib->readpads (&pads);

    int ngotvals = 0;
    Tcl_Obj *gotvals[objc];
    for (int i = 0; ++ i < objc;) {
        char const *regname = Tcl_GetString (objv[i]);
        uint16_t regval = 0xFFFFU;
        if (strcasecmp (regname, "ac")   == 0) regval = pads.light.ac;
        if (strcasecmp (regname, "df")   == 0) regval = pads.light.dfld;
        if (strcasecmp (regname, "ea")   == 0) regval = pads.light.ema;
        if (strcasecmp (regname, "ir")   == 0) regval = pads.light.ir;
        if (strcasecmp (regname, "ma")   == 0) regval = pads.light.ma;
        if (strcasecmp (regname, "mb")   == 0) regval = pads.light.mb;
        if (strcasecmp (regname, "mq")   == 0) regval = pads.light.mq;
        if (strcasecmp (regname, "if")   == 0) regval = pads.light.ifld;
        if (strcasecmp (regname, "ion")  == 0) regval = pads.light.ion;
        if (strcasecmp (regname, "link") == 0) regval = pads.light.link;
        if (strcasecmp (regname, "pc")   == 0) regval = pads.light.pc;
        if (strcasecmp (regname, "run")  == 0) regval = pads.light.run;
        if (strcasecmp (regname, "sc")   == 0) regval = pads.light.sc;
        if (regval != 0xFFFFU) {
            gotvals[ngotvals++] = Tcl_NewIntObj (regval);
            continue;
        }
        if (strcasecmp (regname, "ms") == 0) {
            regval = pads.light.ms;
            if (regval >= sizeof msnames / sizeof msnames[0]) {
                gotvals[ngotvals++] = Tcl_NewIntObj (regval);
            } else {
                char const *msname = msnames[regval];
                gotvals[ngotvals++] = Tcl_NewStringObj ((char *)msname, -1);
            }
            continue;
        }
        Tcl_SetResultF (interp, "bad light bulb name %s", regname);
        return TCL_ERROR;
    }

    if (ngotvals > 0) {
        if (ngotvals < 2) {
            Tcl_SetObjResult (interp, gotvals[0]);
        } else {
            Tcl_SetObjResult (interp, Tcl_NewListObj (ngotvals, gotvals));
        }
    }
    return TCL_OK;
}

// get switch
static int cmd_getsw (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    Switches sws;

    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts (" getsw <switchname>...");
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            printf ("      %s\n", sw->name);
        }
        puts ("");
        return TCL_OK;
    }

    int ngotvals = 0;
    Tcl_Obj *gotvals[objc];
    for (int i = 0; ++ i < objc;) {
        char const *swname = Tcl_GetString (objv[i]);
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            if (strcasecmp (swname, sw->name) == 0) {
                uint16_t swval = sw->get ();
                gotvals[ngotvals++] = Tcl_NewIntObj (swval);
                goto gotit;
            }
        }
        Tcl_SetResultF (interp, "bad switch name %s", swname);
        return TCL_ERROR;
gotit:;
    }

    if (ngotvals > 0) {
        if (ngotvals < 2) {
            Tcl_SetObjResult (interp, gotvals[0]);
        } else {
            Tcl_SetObjResult (interp, Tcl_NewListObj (ngotvals, gotvals));
        }
    }
    return TCL_OK;
}

// read character with timeout as an integer
// returns null string if timeout, else decimal integer
//  readchar file timeoutms
static int cmd_readchar (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    if (objc == 3) {
        char const *stri = Tcl_GetString (objv[1]);
        int fd = STDIN_FILENO;
        if (strcmp (stri, "stdin") != 0) {
            if (memcmp (stri, "file", 4) != 0) {
                Tcl_SetResultF (interp, "first argument not a file");
                return TCL_ERROR;
            }
            fd = atoi (stri + 4);
        }
        int tmoms;
        int rc = Tcl_GetIntFromObj (interp, objv[2], &tmoms);
        if (rc != TCL_OK) return rc;
        struct pollfd fds = { fd, POLLIN, 0 };
        rc = poll (&fds, 1, tmoms);
        uint8_t buff;
        if (rc > 0) rc = read (fd, &buff, 1);
        if (rc < 0) {
            if (errno == EINTR) return TCL_OK;
            Tcl_SetResultF (interp, "%m");
            return TCL_ERROR;
        }
        if (rc > 0) Tcl_SetResultF (interp, "%u", (uint32_t) buff);
        return TCL_OK;
    }

    Tcl_SetResult (interp, (char *) "bad number of arguments", TCL_STATIC);
    return TCL_ERROR;
}

// release switch override
static int cmd_relsw (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    Switches sws;

    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts (" relsw all | <switchname>...");
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            printf ("      %s\n", sw->name);
        }
        puts ("");
        return TCL_OK;
    }

    for (int i = 0; ++ i < objc;) {
        char const *swname = Tcl_GetString (objv[i]);
        if (strcasecmp (swname, "all") == 0) {
            for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
                sw->rel ();
            }
            return TCL_OK;
        }
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            if (strcasecmp (swname, sw->name) == 0) {
                sw->rel ();
                goto gotit;
            }
        }
        Tcl_SetResultF (interp, "bad switch name %s", swname);
        return TCL_ERROR;
    gotit:;
    }
    return TCL_OK;
}

// set switch
static int cmd_setsw (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    Switches sws;

    if ((objc == 2) && (strcasecmp (Tcl_GetString (objv[1]), "help") == 0)) {
        puts ("");
        puts (" setsw <switchname> <switchvalue>...");
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            printf ("      %s\n", sw->name);
        }
        puts ("");
        return TCL_OK;
    }

    for (int i = 0; i + 2 < objc;) {
        char const *swname = Tcl_GetString (objv[++i]);
        int swval = 0;
        int rc = Tcl_GetIntFromObj (interp, objv[++i], &swval);
        if (rc != TCL_OK) return rc;
        for (Switch const *sw = sws.list; sw->name != NULL; sw ++) {
            if (strcasecmp (swname, sw->name) == 0) {
                if (! sw->set (swval)) {
                    Tcl_SetResultF (interp, "value %d (0%o) out of range for switch %s", swval, swval, swname);
                    return TCL_ERROR;
                }
                goto gotit;
            }
        }
        Tcl_SetResultF (interp, "bad switch name %s", swname);
        return TCL_ERROR;
    gotit:;
    }
    return TCL_OK;
}



// get list of switches
Switches::Switches ()
{
    Switch swlist[] = {
        { this, "cont",  1, NULL,               &pads.button.cont  },
        { this, "depos", 1, NULL,               &pads.button.depos },
        { this, "dfld",  3, &pads.togovr.dfld,  &pads.togval.dfld  },
        { this, "exam",  1, NULL,               &pads.button.exam  },
        { this, "ifld",  3, &pads.togovr.ifld,  &pads.togval.ifld  },
        { this, "ldad",  1, NULL,               &pads.button.ldad  },
        { this, "reg",  12, &pads.togovr.reg,   &pads.togval.reg   },
        { this, "start", 1, NULL,               &pads.button.start },
        { this, "sinst", 1, &pads.togovr.sinst, &pads.togval.sinst },
        { this, "sstep", 1, &pads.togovr.sstep, &pads.togval.sstep },
        { this, "stop",  1, NULL,               &pads.button.stop  },
        { this, NULL }
    };

    void *ptr = malloc (sizeof swlist);
    if (ptr == NULL) ABORT ();
    memcpy (ptr, swlist, sizeof swlist);
    list = (Switch const *) ptr;

    mademods = false;
    padlib->lockpads ();
    padlib->readpads (&pads);
}

Switches::~Switches ()
{
    if (mademods) {
        padlib->writepads (&pads);
    }
    padlib->unlkpads ();
}

uint32_t Switch::get () const
{
    switch (nbits) {
        case  1: {
            return *(bool *)valptr;
        }
        case  3: {
            return *(uint8_t *)valptr;
        }
        case 12: {
            return *(uint16_t *)valptr;
        }
        default: ABORT ();
    }
}

void Switch::rel () const
{
    switch (nbits) {
        case 1: {
            if (ovrptr != NULL) *(bool *)ovrptr = false;  // toggle - explicit release
                           else *(bool *)valptr = false;  // button - release by clearing
            break;
        }
        case 3: {
            if (ovrptr != NULL) *(uint8_t *)ovrptr = 0;
                           else *(uint8_t *)valptr = 0;
            break;
        }
        case 12: {
            if (ovrptr != NULL) *(uint16_t *)ovrptr = 0;
                           else *(uint16_t *)valptr = 0;
            break;
        }
        default: ABORT ();
    }
    sws->mademods = true;
}

bool Switch::set (uint32_t val) const
{
    uint16_t mask = (1 << nbits) - 1;
    if (val > mask) return false;

    switch (nbits) {
        case 1: {
            *(bool *)valptr = val;
            if (ovrptr != NULL) *(bool *)ovrptr = true;
            break;
        }
        case 3: {
            *(uint8_t *)valptr = val;
            if (ovrptr != NULL) *(uint8_t *)ovrptr = 7;
            break;
        }
        case 12: {
            *(uint16_t *)valptr = val;
            if (ovrptr != NULL) *(uint16_t *)ovrptr = 07777;
            break;
        }
        default: ABORT ();
    }
    sws->mademods = true;
    return true;
}



// continuously display what should be on the PDP-8/I front panel

#define ESC_NORMV "\033[m"             /* go back to normal video */
#define ESC_REVER "\033[7m"            /* turn reverse video on */
#define ESC_UNDER "\033[4m"            /* turn underlining on */
#define ESC_BLINK "\033[5m"            /* turn blink on */
#define ESC_BOLDV "\033[1m"            /* turn bold on */

#define ESC_BLKFG "\033[30m"           /* foreground */
#define ESC_REDFG "\033[31m"
#define ESC_GRNFG "\033[32m"
#define ESC_YELFG "\033[33m"
#define ESC_BLUFG "\033[34m"
#define ESC_MAGFG "\033[35m"
#define ESC_CYNFG "\033[36m"
#define ESC_WHTFG "\033[37m"

#define ESC_BLKBG "\033[40m"           /* background */
#define ESC_REDBG "\033[41m"
#define ESC_GRNBG "\033[42m"
#define ESC_YELBG "\033[43m"
#define ESC_BLUBG "\033[44m"
#define ESC_MAGBG "\033[45m"
#define ESC_CYNBG "\033[46m"
#define ESC_WHTBG "\033[47m"

#define ESC_EREOL "\033[K"             /* erase to end of line */
#define ESC_EREOP "\033[J"             /* erase to end of page */
#define ESC_HOME  "\033[H"             /* home cursor */

#define ESC_ON ESC_BOLDV ESC_GRNBG ESC_BLKFG
#define ESC_OFF ESC_NORMV

static char const redbiton [] = ESC_BOLDV ESC_REDBG ESC_BLKFG "*" ESC_NORMV;
static char const redbitoff[] =           ESC_REDFG           "-" ESC_NORMV;

static char const yelbiton [] = ESC_BOLDV ESC_YELBG ESC_BLKFG "*" ESC_NORMV;
static char const yelbitoff[] =           ESC_YELFG           "-" ESC_NORMV;

static char const blubiton [] = ESC_BOLDV ESC_CYNBG ESC_BLKFG "*" ESC_NORMV;
static char const blubitoff[] =           ESC_CYNFG           "-" ESC_NORMV;

static char const grnbiton [] = ESC_BOLDV ESC_GRNBG ESC_BLKFG "*" ESC_NORMV;
static char const grnbitoff[] =           ESC_GRNFG           "-" ESC_NORMV;

#define REG12L(v) REG3L (red, (v) >> 9), REG3L (yel, (v) >> 6), REG3L (red, (v) >> 3), REG3L (yel, (v) >> 0)
#define REG3L(c,v) RBITL (c, (v), 2), RBITL (c, (v), 1), RBITL (c, (v), 0)
#define REG5L(v) RBITL (blu, (v), 4), RBITL (blu, (v), 3), RBITL (grn, (v), 2), RBITL (grn, (v), 1), RBITL (grn, (v), 0)
#define RBITL(c,v,n) BOOL (c, ((v) >> (n)) & 1)
#define BOOL(c,b) (b ? c##biton : c##bitoff)
#define STL(c,b,on,off) (b ? (ESC_BOLDV ESC_##c##BG ESC_BLKFG on ESC_NORMV) : (ESC_##c##FG off ESC_NORMV))

#define TOP ESC_HOME
#define EOL ESC_EREOL "\n"
#define EOP ESC_EREOP

static char outbuf[6000];

static int showstatus (int argc, char **argv)
{
    uint32_t fps = 0;
    uint32_t nframes = 0;
    time_t lasttime = 0;

    Z8IU32 *pdpat = z8ipage.findev ("8I", NULL, NULL, false);
    padlib = new I2CZLib ();

    setvbuf (stdout, outbuf, _IOFBF, sizeof outbuf);

    int twirly = 0;

    while (true) {
        struct timeval tvnow;
        if (gettimeofday (&tvnow, NULL) < 0) ABORT ();
        usleep (50000 - tvnow.tv_usec % 50000);

        // measure updates per second
        time_t thistime = time (NULL);
        if (lasttime < thistime) {
            if (lasttime > 0) {
                fps = nframes / (thistime - lasttime);
            }
            lasttime = thistime;
            nframes  = 0;
        }
        ++ nframes;

        // read bulbs and switches
        Z8IPanel pads;
        padlib->readpads (&pads);

        bool irand = pads.light.ir == 0;
        bool irtad = pads.light.ir == 1;
        bool irisz = pads.light.ir == 2;
        bool irdca = pads.light.ir == 3;
        bool irjms = pads.light.ir == 4;
        bool irjmp = pads.light.ir == 5;
        bool iriot = pads.light.ir == 6;
        bool iropr = pads.light.ir == 7;

        bool msfet = pads.light.ms == MS_FETCH;
        bool msdef = pads.light.ms == MS_DEFER;
        bool msexe = pads.light.ms == MS_EXEC;
        bool mswct = pads.light.ms == MS_WRDCT;
        bool mscad = pads.light.ms == MS_CURAD;
        bool msbrk = pads.light.ms == MS_BREAK;
        bool msiak = pads.light.ms == MS_INTAK;
        bool msdep = pads.light.ms == MS_DEPOS;
        bool msexm = pads.light.ms == MS_EXAM;

        char const *simit = (pdpat[Z_RE] & e_simit) ? " SIM" : "REAL";

        // display it
        printf (TOP ESC_NORMV EOL);

        printf (" " ESC_BOLDV " PDP-8/I " ESC_NORMV "   %s %s %s  %s %s %s   %s %s %s  %s %s %s  %s %s %s  %s %s %s  PC  " ESC_BOLDV "%o%o.%04o" ESC_NORMV "  %s  %s  %s" EOL,
            REG3L (blu, pads.light.dfld), REG3L (grn, pads.light.ifld), REG12L (pads.light.pc), pads.light.dfld, pads.light.ifld, pads.light.pc,
            STL (CYN, irand, "AND", "and"), STL (GRN, msfet, "FETCH", "fetch"), STL (CYN, pads.light.ion, " ION ", " ion "));

        printf ("             " ESC_CYNFG " DF " ESC_NORMV "   " ESC_GRNFG " IF " ESC_NORMV "                                             %s  %s  %s" EOL,
            STL (CYN, irtad, "TAD", "tad"), STL (GRN, msexe, "EXEC ", "exec "), STL (CYN, pads.light.pau, "PAUSE", "pause"));

        printf ("                            %s %s %s  %s %s %s  %s %s %s  %s %s %s  MA  " ESC_BOLDV "   %04o" ESC_NORMV "  %s  %s  %s" EOL,
            REG12L (pads.light.ma), pads.light.ma,
            STL (CYN, irisz, "ISZ", "isz"), STL (GRN, msdef, "DEFER", "defer"), STL (CYN, pads.light.run, " RUN ", " run "));

        printf ("                                                                     %s  %s" EOL,
            STL (CYN, irdca, "DCA", "dca"), STL (GRN, mswct, "WRDCT", "wrdct"));

        printf ("                            %s %s %s  %s %s %s  %s %s %s  %s %s %s  MB  " ESC_BOLDV "   %04o" ESC_NORMV "  %s  %s" EOL,
            REG12L (pads.light.mb), pads.light.mb,
            STL (CYN, irjms, "JMS", "jms"), STL (GRN, mscad, "CURAD", "curad"));

        printf ("                                                                     %s  %s" EOL,
            STL (CYN, irjmp, "JMP", "jmp"), STL (GRN, msbrk, "BREAK", "break"));

        printf ("                    " ESC_GRNFG " L " ESC_NORMV " %s   %s %s %s  %s %s %s  %s %s %s  %s %s %s  AC  " ESC_BOLDV " %o.%04o" ESC_NORMV "  %s  %s" EOL,
            BOOL (grn, pads.light.link), REG12L (pads.light.ac), pads.light.link, pads.light.ac,
            STL (CYN, iriot, "IOT", "iot"), STL (GRN, msiak, "INTAK", "intak"));

        printf ("                                                                     %s  %s" EOL,
            STL (CYN, iropr, "OPR", "opr"), STL (GRN, msdep, "DEPOS", "depos"));

        printf ("          " ESC_CYNFG " SC " ESC_NORMV " %s %s  %s %s %s   %s %s %s  %s %s %s  %s %s %s  %s %s %s  MQ  " ESC_BOLDV "%02o.%04o" ESC_NORMV "       %s" EOL,
            REG5L (pads.light.sc), REG12L (pads.light.mq), pads.light.sc, pads.light.mq, STL (GRN, msexm, "EXAM ", "exam "));

        printf (EOL);

        printf ("             %s %s %s  %s %s %s   %s %s %s  %s %s %s  %s %s %s  %s %s %s  SR  " ESC_BOLDV "%o%o.%04o" ESC_NORMV "  %s %s %s %s" EOL,
            REG3L (blu, pads.togval.dfld), REG3L (grn, pads.togval.ifld), REG12L (pads.togval.reg), pads.togval.dfld, pads.togval.ifld, pads.togval.reg,
            STL (CYN, pads.button.start, "START", "start"), STL (GRN, pads.button.ldad, "LDAD", "ldad"),
            STL (CYN, pads.button.depos, "DEPOS", "depos"), STL (GRN, pads.button.exam, "EXAM", "exam"));

        printf ("                                                                     %s %s %s %s" EOL EOP,
            STL (CYN, pads.button.cont, "CONT", "cont"), STL (GRN, pads.button.stop, "STOP", "stop"),
            STL (CYN, pads.togval.sstep, "SSTEP", "sstep"), STL (GRN, pads.togval.sinst, "SINST", "sinst"));

        printf ("    %c %6u fps   %s\r", "\\|/-"[++twirly&3], fps, simit);
        fflush (stdout);
    }
}
