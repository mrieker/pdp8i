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

// test physical zturn board plugged into tester board
// on tester board raspi: ./testzturn -server
// on zturn: ./testzturn <ipaddressofraspi>

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "testlib.h"

#include "../ccode/z8idefs.h"
#include "../ccode/z8iutil.h"

#define TCPPORT 23451

// inputs to the ZTURN board
static int const zturn_impins[] = {
    mp__ACUM_0, mp__ACUM_1, mp__ACUM_2, mp__ACUM_3, mp__ACUM_4, mp__ACUM_5,
    mp__ACUM_6, mp__ACUM_7, mp__ACUM_8, mp__ACUM_9, mp__ACUM_10, mp__ACUM_11,
    mp__BRKCYC, mp__BRKGNTI, mp__BRKRQST, mp__BUSINI, mp__BWCOV, mp__IOP, mp__LINK,
    mp__MADR_0, mp__MADR_1, mp__MADR_2, mp__MADR_3, mp__MADR_4, mp__MADR_5,
    mp__MADR_6, mp__MADR_7, mp__MADR_8, mp__MADR_9, mp__MADR_10, mp__MADR_11,
    mp__MBUF_0, mp__MBUF_1, mp__MBUF_2, mp__MBUF_3, mp__MBUF_4, mp__MBUF_5,
    mp__MBUF_6, mp__MBUF_7, mp__MBUF_8, mp__MBUF_9, mp__MBUF_10, mp__MBUF_11,
    mp__MEAD_0, mp__MEAD_1, mp__MEAD_2, mp__MAJST_0, mp__MAJST_1, mp__MAJST_2, mp__MAJST_3,
    mp__RUN, mp__TP1, mp__TP2, mp__TP3, mp__TP4, mp__TS1, mp__TS2, mp__TS3, mp__TS4, 0 };

// outputs from the ZTURN board
static int const zturn_ompins[] = {
    mp__ACCLEAR, mp__BRKGNTO, mp__BRKRQST, mp__BRKWRM, mp__CAINC, mp__CLOCK, mp__CYCLE3,
    mp__DMAFLD_0, mp__DMAFLD_1, mp__DMAFLD_2,
    mp__INBUS_0, mp__INBUS_1, mp__INBUS_2, mp__INBUS_3, mp__INBUS_4, mp__INBUS_5,
    mp__INBUS_6, mp__INBUS_7, mp__INBUS_8, mp__INBUS_9, mp__INBUS_10, mp__INBUS_11,
    mp__INTRQST, mp__IOSKIP, mp__MEMDIS, mp__PAUSE, mp__RESET, 0 };

static volatile bool ctrlcflag;
//static uint32_t errors;
static uint32_t errors, passes;

static int readpipe (int fd, void *buff, int len);
static int writepipe (int fd, void *buff, int len);
static void sighand (int signum);
static void server ();
static void client (char const *server);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    signal (SIGINT, sighand);

    if (argc == 2) {
        if (strcasecmp (argv[1], "-server") == 0) server ();
        else client (argv[1]);
    }
    return 0;
}

static int readpipe (int fd, void *buff, int len)
{
    char *ptr = (char *)buff;
    while (len > 0) {
        int rc = read (fd, ptr, len);
        if (rc <= 0) {
            if (rc == 0) errno = EPIPE;
            return -1;
        }
        ptr += rc;
        len -= rc;
    }
    return 0;
}

static int writepipe (int fd, void *buff, int len)
{
    char *ptr = (char *)buff;
    while (len > 0) {
        int rc = write (fd, ptr, len);
        if (rc <= 0) {
            if (rc == 0) errno = EPIPE;
            return -1;
        }
        ptr += rc;
        len -= rc;
    }
    return 0;
}

static void sighand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
    write (0, "\n", 1);
}

// running on raspi
static void server ()
{
    // access tester board mcp23017s and set pin directions
    setmpinmask (boardipinmask, zturn_impins);
    setmpinmask (boardopinmask, zturn_ompins);
    mcpsetdir ();

    // set up TCP server port
    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof servaddr);
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(TCPPORT);
    int lisfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lisfd < 0) {
        fprintf(stderr, "socket error: %s\n", strerror(errno));
        ABORT ();
    }
    int one = 1;
    if (setsockopt(lisfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one) < 0) {
        fprintf(stderr, "SO_REUSEADDR error: %s\n", strerror(errno));
        ABORT ();
    }
    if (bind(lisfd, (sockaddr *)&servaddr, sizeof servaddr) < 0) {
        fprintf(stderr, "bind error: %s\n", strerror(errno));
        ABORT ();
    }
    if (listen(lisfd, 5) < 0) {
        fprintf(stderr, "listen error: %s\n", strerror(errno));
        ABORT ();
    }

    while (! ctrlcflag) {

        // accept inbound connection from zturn
        printf ("listening on %d\n", TCPPORT);
        socklen_t addrlen = sizeof servaddr;
        memset (&servaddr, 0, sizeof servaddr);
        int confd = accept (lisfd, (sockaddr *) &servaddr, &addrlen);
        if (confd < 0) {
            fprintf (stderr, "error accepting connection: %m\n");
            usleep (100000);
            continue;
        }
        printf ("connected from %s\n", inet_ntoa (servaddr.sin_addr));

        // receive from zturn, update pins, read pins, send to zturn
        while (! ctrlcflag) {
            if (readpipe (confd, mcppins, sizeof mcppins) < 0) {
                fprintf (stderr, "error receiving from client: %m\n");
                break;
            }
            mcpsend ();
            mcprecv ();
            if (writepipe (confd, mcppins, sizeof mcppins) < 0) {
                fprintf (stderr, "error sending to client: %m\n");
                break;
            }
        }
        close (confd);
    }
}

static char qq (uint16_t x, uint16_t fb_x)
{
    bool ok = (x == fb_x);
    if (! ok) errors ++;
    return ok ? '=' : '#';
}

// runs on the zturn
static void client (char const *server)
{
    // connect to the server on raspi plugged into tester board
    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof servaddr);
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons (TCPPORT);
    if (!inet_aton(server, &servaddr.sin_addr)) {
        struct hostent *he = gethostbyname(server);
        if (he == NULL) {
            fprintf(stderr, "bad server address %s\n", server);
            ABORT ();
        }
        if ((he->h_addrtype != AF_INET) || (he->h_length != 4)) {
            fprintf(stderr, "bad server addr type\n");
            ABORT ();
        }
        servaddr.sin_addr = *(struct in_addr *)he->h_addr;
    }

    int confd = socket(AF_INET, SOCK_STREAM, 0);
    if (confd < 0) {
        fprintf(stderr, "socket error: %s\n", strerror(errno));
        ABORT ();
    }
    if (connect (confd, (sockaddr *)&servaddr, sizeof servaddr) < 0) {
        fprintf(stderr, "connect %s:%u error: %s\n",
                inet_ntoa(servaddr.sin_addr), ntohs(servaddr.sin_port),
                strerror(errno));
        close (confd);
        ABORT ();
    }

    // access the zturn 4K register page
    Z8IU32 *pdpat = z8ipage.findev ("8I", NULL, NULL, false);
    pdpat[Z_RE] = e_arm_ioenabd | e_arm_dmagntd; // e_simit = 0, so the Z_RA signals go out to the bus
    pdpat[Z_RD] = 0; // d_clkratm1 = 0, ie, manual clocking so we can manipulate bus clock signal directly

    while (! ctrlcflag) {

        // make up random values

        // - values output by zturn to bus
        bool     acclear = randbits (1);
        bool     brkgnto = randbits (1);
//      bool     brkrqst = randbits (1);
        bool     brkwrm  = randbits (1);
        bool     cainc   = randbits (1);
        bool     clock   = randbits (1);
        bool     cycle3  = randbits (1);
        bool     intrqst = randbits (1);
        bool     ioskip  = randbits (1);
        bool     memdis  = randbits (1);
        bool     pause   = randbits (1);
        bool     reset   = 0; //////// randbits (1);
        uint16_t dmafld  = randbits (3);
        uint16_t inbus   = randbits (12);

        // - values input by zturn from bus
        uint16_t acum    = randbits (12);
        bool     brkcyc  = randbits (1);
        bool     brkgnti = randbits (1);
//      bool     brkrqst = randbits (1);
        bool     busini  = randbits (1);
        bool     bwcov   = randbits (1);
        bool     iop     = 0; //////// randbits (1);  //???? no I/O cycles
        bool     link    = randbits (1);
        uint16_t madr    = randbits (12);
        uint16_t mbuf    = randbits (12);
        uint16_t mead    = randbits (3);
        uint16_t majst   = randbits (4);
        bool     run     = randbits (1);
        bool     tp1     = randbits (1);
        bool     tp2     = randbits (1);
        bool     tp3     = randbits (1);
        bool     tp4     = randbits (1);
        bool     ts1     = randbits (1);
        bool     ts2     = randbits (1);
        bool     ts3     = randbits (1);
        bool     ts4     = randbits (1);

        ///////if (iop) mbuf = 0;  // block i/o cycle from actually triggering zynq internal i/o devices

        // send bits out the zturn pins to the bus
        //  arm_iACCLEAR = regctla[00]
        //  dev_iACCLEAR = arm_iACCLEAR | ...
        //  hdw_iACCLEAR = simit ? 0 : dev_iACCLEAR
        //  _busACCLEAR  = ~ hdw_iACCLEAR
        uint32_t ra =
            (acclear ? a_arm_iACCLEAR : 0) |
            (brkgnto ? a_arm_iBRKGNTO : 0) |
//          (brkrqst ? a_arm_iBRKRQST : 0) |
            (brkwrm  ? a_arm_iBRKWRM  : 0) |
            (cainc   ? a_arm_iCAINC   : 0) |
            (clock   ? a_arm_iCLOCK   : 0) |
            (cycle3  ? a_arm_iCYCLE3  : 0) |
            (intrqst ? a_arm_iINTRQST : 0) |
            (ioskip  ? a_arm_iIOSKIP  : 0) |
            (memdis  ? a_arm_iMEMDIS  : 0) |
            (pause   ? a_arm_iPAUSE   : 0) |
            (reset   ? a_arm_iRESET   : 0) |
            INS (dmafld, a_arm_iDMAFLD) |
            INS (inbus,  a_arm_iINBUS);
        pdpat[Z_RA] = ra;

        // send bits out the tester pins to the bus
        setmpins (mps__ACUM,     acum ^ 07777);
        setmpin  (mp__BRKCYC,  ! brkcyc);
        setmpin  (mp__BRKGNTI, ! brkgnti);
//      setmpin  (mp__BRKRQST, ! brkrqst);
        setmpin  (mp__BUSINI,  ! busini);
        setmpin  (mp__BWCOV,   ! bwcov);
        setmpin  (mp__IOP,     ! iop);
        setmpin  (mp__LINK,    ! link);
        setmpins (mps__MADR,    madr ^ 07777);
        setmpins (mps__MBUF,    mbuf ^ 07777);
        setmpins (mps__MEAD,    mead ^ 7);
        setmpins (mps__MAJST,   majst ^ 017);
        setmpin  (mp__RUN,    ! run);
        setmpin  (mp__TP1,    ! tp1);
        setmpin  (mp__TP2,    ! tp2);
        setmpin  (mp__TP3,    ! tp3);
        setmpin  (mp__TP4,    ! tp4);
        setmpin  (mp__TS1,    ! ts1);
        setmpin  (mp__TS2,    ! ts2);
        setmpin  (mp__TS3,    ! ts3);
        setmpin  (mp__TS4,    ! ts4);
        if (writepipe (confd, mcppins, sizeof mcppins) < 0) {
            fprintf (stderr, "error sending to server: %m\n");
            break;
        }

        // receive bus bits from tester pins
        if (readpipe (confd, mcppins, sizeof mcppins) < 0) {
            fprintf (stderr, "error receiving from server: %m\n");
            break;
        }
        bool     fb_acclear = ! getmpin (mp__ACCLEAR);
        bool     fb_brkgnto = ! getmpin (mp__BRKGNTO);
//      bool     fb_brkrqst = ! getmpin (mp__BRKRQST);
        bool     fb_brkwrm  = ! getmpin (mp__BRKWRM);
        bool     fb_cainc   = ! getmpin (mp__CAINC);
        bool     fb_clock   = ! getmpin (mp__CLOCK);
        bool     fb_cycle3  = ! getmpin (mp__CYCLE3);
        bool     fb_intrqst = ! getmpin (mp__INTRQST);
        bool     fb_ioskip  = ! getmpin (mp__IOSKIP);
        bool     fb_memdis  = ! getmpin (mp__MEMDIS);
        bool     fb_pause   = ! getmpin (mp__PAUSE);
        bool     fb_reset   = ! getmpin (mp__RESET);
        uint16_t fb_dmafld  = getmpins (mps__DMAFLD) ^ 7;
        uint16_t fb_inbus   = getmpins (mps__INBUS)  ^ 07777;

        // read bits from zturn pins
        uint32_t re = pdpat[Z_RE];
        uint32_t rf = pdpat[Z_RF];
        uint16_t fb_acum    = EXT (rf, f_oACUM);
        bool     fb_brkcyc  = EXT (rf, f_oBRKCYC);
        bool     fb_brkgnti = EXT (rf, f_oBRKGNTI);
//      bool     fb_brkrqst = EXT (rf, f_oBRKRQST);
        bool     fb_busini  = EXT (rf, f_oBUSINI);
        bool     fb_bwcov   = EXT (rf, f_oBWCOV);
        bool     fb_iop     = EXT (rf, f_oIOP);
        bool     fb_link    = EXT (rf, f_oLINK);
        uint16_t fb_madr    = EXT (re, e_oMADR);
        uint16_t fb_mbuf    = EXT (re, e_oMBUF);
        uint16_t fb_mead    = EXT (re, e_oMEAD);
        uint16_t fb_majst   = EXT (rf, f_oMAJST);
        bool     fb_run     = EXT (rf, f_oRUN);
        bool     fb_tp1     = EXT (rf, f_oTP1);
        bool     fb_tp2     = EXT (rf, f_oTP2);
        bool     fb_tp3     = EXT (rf, f_oTP3);
        bool     fb_tp4     = EXT (rf, f_oTP4);
        bool     fb_ts1     = EXT (rf, f_oTS1);
        bool     fb_ts2     = EXT (rf, f_oTS2);
        bool     fb_ts3     = EXT (rf, f_oTS3);
        bool     fb_ts4     = EXT (rf, f_oTS4);

#define Q(x) x,qq(x,fb_##x),fb_##x

        if (++ passes % 32 == 1) {
            printf ("                    acclear brkgnto brkwrm cainc clock cycle3 intrqst ioskip memdis pause reset dmafld   inbus       acum     brkcyc brkgnti busini bwcov iop link   madr      mbuf    mead majst run tp1 tp2 tp3 tp4 ts1 ts2 ts3 ts4\n");
        }
        printf ("%8u  %8u    %o%c%o     %o%c%o    %o%c%o    %o%c%o   %o%c%o   %o%c%o     %o%c%o    %o%c%o    %o%c%o    %o%c%o   %o%c%o   %o%c%o   %04o%c%04o   %04o%c%04o   %o%c%o     %o%c%o    %o%c%o    %o%c%o  %o%c%o %o%c%o  %04o%c%04o %04o%c%04o %o%c%o   %X%c%X  %o%c%o %o%c%o %o%c%o %o%c%o %o%c%o %o%c%o %o%c%o %o%c%o %o%c%o\n",
            errors, passes, Q(acclear),Q(brkgnto),Q(brkwrm),Q(cainc),Q(clock),Q(cycle3),Q(intrqst),Q(ioskip),Q(memdis),Q(pause),Q(reset),Q(dmafld),Q(inbus),Q(acum),Q(brkcyc),Q(brkgnti),Q(busini),Q(bwcov),Q(iop),Q(link),Q(madr),Q(mbuf),Q(mead),Q(majst),Q(run),Q(tp1),Q(tp2),Q(tp3),Q(tp4),Q(ts1),Q(ts2),Q(ts3),Q(ts4));
    }

    printf ("resetting\n");
    pdpat[Z_RE] = 0; // e_arm_ioenabd=0 e_arm_dmagntd=0 e_simit=0
}
