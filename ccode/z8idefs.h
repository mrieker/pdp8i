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

// bits provided by zynq.v in the zynq

#ifndef _Z8IDEFS
#define _Z8IDEFS

#define Z_VER 0     // zynq.v version number
#define Z_RA 1      // contain the various bits
#define Z_RB 2
#define Z_RC 3
#define Z_RD 4
#define Z_RE 5
#define Z_RF 6
#define Z_RG 7
#define Z_RH 8
#define Z_RI 9
#define Z_RJ 10
#define Z_RK 11
#define Z_RL 12
#define Z_RM 13
#define Z_RN 14     // memcycctr
#define Z_RO 15
#define Z_RP 16
#define Z_RQ 17

#define LB(mask) ((mask)&-(mask))                   // low bit of a mask
#define EXT(wrd,msk) (((wrd) & (msk)) / LB(msk))    // extract field from word
#define INS(val,msk) (((val) * LB(msk)) & (msk))    // insert field into word

#define a_arm_iACCLEAR      (1U <<  0)
#define a_arm_iBRKGNTO      (1U <<  1)
#define a_arm_iBRKRQST      (1U <<  2)
#define a_arm_iBRKWRM       (1U <<  3)
#define a_arm_iCAINC        (1U <<  4)
#define a_arm_iCYCLE3       (1U <<  5)
#define a_arm_iDMAFLD       (7U <<  6)
#define a_arm_iINBUS    (07777U <<  9)
#define a_arm_iINTRQST      (1U << 21)
#define a_arm_iIOSKIP       (1U << 22)
#define a_arm_iMEMDIS       (1U << 23)
#define a_arm_iPAUSE        (1U << 24)

#if 000
#define b_arm_swCONT        (1U <<  0)
#define b_arm_swDEPOS       (1U <<  1)
#define b_arm_swDFLD        (7U <<  2)
#define b_arm_swEXAM        (1U <<  5)
#define b_arm_swIFLD        (7U <<  6)
#define b_arm_swLDAD        (1U <<  9)
#define b_arm_swSINST       (1U << 10)
#define b_arm_swSSTEP       (1U << 11)
#define b_arm_swSTART       (1U << 12)
#define b_arm_swSR      (07777U << 13)
#endif

#define c_dev_iACCLEAR      (1U <<  0)
#define c_dev_iBRKGNTO      (1U <<  1)
#define c_dev_iBRKRQST      (1U <<  2)
#define c_dev_iBRKWRM       (1U <<  3)
#define c_dev_iCAINC        (1U <<  4)
#define c_dev_iCYCLE3       (1U <<  5)
#define c_dev_iDMAFLD       (7U <<  6)
#define c_dev_iINBUS    (07777U <<  9)
#define c_dev_iINTRQST      (1U << 21)
#define c_dev_iIOSKIP       (1U << 22)
#define c_dev_iMEMDIS       (1U << 23)
#define c_dev_iPAUSE        (1U << 24)
#define c_dev_iCLOCK        (1U << 25)
#define c_dev_iRESET        (1U << 26)

#define d_clkratm1     (077U << 0)  //rw clock ratio minus 1, eg, 9 for 10MHz = 100MHz / (d_clkratm1 + 1)

#define e_simit         (1U <<  0)  //rw 0=real PDP-8/I; 1=pdp8isim.v
#define e_fpgareset     (1U <<  1)  //rw 0=normal; 1=power-on-reset
#define e_nanocontin    (1U <<  2)  //rw 0=single step mode (sim only); 1=normal continuous running
#define e_nanotrigger   (1U <<  3)  //rw 0=ignored; 1=trigger single step (sim only)
#define e_nanocstep     (1U <<  4)  //ro 0=stopped; 1=stepping
#define e_oMADR     (07777U <<  5)  //ro dev_oMADR
#define e_oMEAD         (7U << 17)  //ro dev_oMEAD
#define e_oMBUF     (07777U << 20)  //ro dev_oMBUF
#define e_oMADX  (e_oMEAD|e_oMADR)  //ro extended memory address

#define f_oACUM     (07777U <<  0)  //ro dev_...
#define f_oBRKCYC       (1U << 12)
#define f_oBRKGNTI      (1U << 13)
#define f_oBRKRQST      (1U << 14)
#define f_oBUSINI       (1U << 15)
#define f_oBWCOV        (1U << 16)
#define f_oIOP          (1U << 17)
#define f_oLINK         (1U << 18)
#define f_oRUN          (1U << 19)
#define f_oTP1          (1U << 20)
#define f_oTP2          (1U << 21)
#define f_oTP3          (1U << 22)
#define f_oTP4          (1U << 23)
#define f_oTS1          (1U << 24)
#define f_oTS2          (1U << 25)
#define f_oTS3          (1U << 26)
#define f_oTS4          (1U << 27)
#define f_oMAJST      (017U << 28)

#define h_100MHz       0xFFFFFFFFU

#if 000
#define g_lbAC      (07777U <<  0)  //ro sim_...
#define g_lbMA      (07777U << 12)
#define g_lbSC        (037U << 24)
#define g_lbION         (1U << 29)
#define g_lbLINK        (1U << 30)
#define g_lbPAU         (1U << 31)
#define h_lbMB      (07777U <<  0)
#define h_lbMQ      (07777U << 12)
#define h_lbMS        (017U << 24)
#define h_lbIR          (7U << 28)
#define h_lbRUN         (1U << 31)
#define i_lbPC      (07777U <<  0)
#define i_lbDF          (7U << 12)
#define i_lbEA          (7U << 15)
#define i_lbIF          (7U << 18)
#endif

#define q_ilaarmed     (1U << 31)
#define q_ilaafter (07777U << 16)
#define q_ilaindex (07777U <<  0)

#define MS_FETCH  1     // memory cycle is fetching instruction
#define MS_DEFER  2     // memory cycle is reading pointer
#define MS_EXEC   3     // memory cycle is for executing instruction
#define MS_WRDCT  4     // memory cycle is for incrementing dma word count
#define MS_CURAD  5     // memory cycle is for reading dma address
#define MS_BREAK  6     // memory cycle is for dma data word transfer
#define MS_INTAK  7     // memory cycle is for interrupt acknowledge
#define MS_DEPOS  8     // memory cycle is for deposit switch
#define MS_EXAM   9     // memory cycle is for examine switch

#define MS_NAMES "????0","FETCH","DEFER","EXEC","WRDCT","CURAD","BREAK","INTAK","DEPOS","EXAM","???10","???11","???12","???13","???14","???15"

// pdp8icmem.v registers
#define CM_ADDR  (077777U << 0)
#define CM_WRITE (1U << 15)
#define CM_DATA  (07777U << 16)
#define CM_CAINC (1U << 28)
#define CM_3CYCL (1U << 29)
#define CM_WCOVF (1U << 30)
#define CM_BUSY  (1U << 31)

#define CM2_BGNT (1U << 0)
#define CM3_LOCK (0xFFFFFFFFU)

// pdp8itty.v registers
#define Z_TTYVER 0
#define Z_TTYKB 1
#define Z_TTYPR 2
#define Z_TTYPN 3

#define KB_FLAG 0x80000000
#define KB_ENAB 0x40000000
#define PR_FLAG 0x80000000
#define PR_FULL 0x40000000

// pdp8ishad.v registers
#define SH_ACKNOWN  (1U << 31)
#define SH_EAKNOWN  (1U << 30)
#define SH_IRKNOWN  (1U << 29)
#define SH_LNKNOWN  (1U << 28)
#define SH_MAKNOWN  (1U << 27)
#define SH_MBKNOWN  (1U << 26)
#define SH_PCKNOWN  (1U << 25)
#define SH_FRZONERR (1U << 17)
#define SH_CLEARIT  (1U << 16)
#define SH_ERROR    (0177777U)

#define SH2_MAJSTATE  (15U << 28)
#define SH2_TIMESTATE (15U << 24)
#define SH2_IREG   (07777U << 12)
#define SH2_PCTR   (07777U <<  0)

#define SH3_TIMEDELAY (15U << 28)
#define SH3_MBUF   (07777U << 12)
#define SH3_MADR   (07777U <<  0)

#define SH4_LINK     (1U << 24)
#define SH4_ACUM (07777U << 12)
#define SH4_EADR (07777U <<  0)

// pdp8ixmem.v registers
#define XM_OS8ZAP (1U <<  0)
#define XM_MWSTEP (1U <<  1)
#define XM_MWHOLD (1U <<  2)
#define XM_MRSTEP (1U <<  3)
#define XM_MRHOLD (1U <<  4)
#define XM_ENLO4K (1U << 30)
#define XM_ENABLE (1U << 31)

#define XM2_XMSTATE   (077U <<  0)
#define XM2_XMMEMENAB   (1U <<  6)
#define XM2_SAVEDIFLD   (7U <<  8)
#define XM2_SAVEDDFLD   (7U << 11)
#define XM2_IFLDAFJMP   (7U << 14)
#define XM2_IFLD        (7U << 17)
#define XM2_DFLD        (7U << 20)
#define XM2_FIELD       (7U << 27)
#define XM2__MWDONE     (1U << 30)
#define XM2__MRDONE     (1U << 31)
#define XM2_XMSTATE0    (1U <<  0)
#define XM2_SAVEDIFLD0  (1U <<  8)
#define XM2_SAVEDDFLD0  (1U << 11)
#define XM2_IFLDAFJMP0  (1U << 14)
#define XM2_IFLD0       (1U << 17)
#define XM2_DFLD0       (1U << 20)
#define XM2_BUSYONARM0  (1U << 24)
#define XM2_FIELD0      (1U << 27)

#define XM3_OS8STEP     (3U <<  0)
#define XM3_OS8STEP0    (1U <<  0)

#define XM4_ADDRLATCHWID  (0377U <<  0)
#define XM4_READSTROBEDEL (0377U <<  8)
#define XM4_READSTROBEWID (0377U << 16)
#define XM4_WRITEENABDEL  (0377U << 24)
#define XM5_WRITEENABWID  (0377U <<  0)
#define XM5_WRITEDONEWID  (0377U <<  8)

#define XM6_MEMCYCCTRLO 0xFFFFFFFFU
#define XM7_MEMCYCCTRHI 0xFFFFFFFFU

// pdp8ivc8.v registers
#define VC1_REMOVE   (077777U << 17)
#define VC1_INSERT   (077777U <<  0)
#define VC2_TYPEE         (1U << 31)
#define VC2_INTENS        (3U << 28)
#define VC2_EFLAGS    (07777U << 16)
#define VC3_DEQUEUE       (1U << 31)
#define VC3_READADDR (077777U <<  0)
#define VC4_READBUSY      (3U << 30)
#define VC4_EMPTY         (1U << 29)
#define VC4_TCOORD        (3U << 20)
#define VC4_YCOORD    (01777U << 10)
#define VC4_XCOORD    (01777U <<  0)

#define VC1_REMOVE0       (1U << 17)
#define VC1_INSERT0       (1U <<  0)
#define VC2_INTENS0       (1U << 28)
#define VC2_EFLAGS0       (1U << 16)
#define VC3_READADDR0     (1U <<  0)
#define VC4_READBUSY0     (1U << 30)
#define VC4_TCOORD0       (1U << 20)
#define VC4_YCOORD0       (1U << 10)
#define VC4_XCOORD0       (1U <<  0)

// pdp8ifpi2c.v
#define FP1_CMDLO 0xFFFFFFFFU
#define FP2_CMDHI 0xFFFFFFFFU
#define FP3_STSLO 0xFFFFFFFFU
#define FP4_STSHI 0xFFFFFFFFU
#define FP5_INMODE       (1U << 1)
#define FP5_MANUAL       (1U << 3)
#define FP5_I2CCOUNT (32767U << 4)
#define FP5_I2CSTATE    (7U << 19)
#define FP5_I2CCLI      (1U << 28)
#define FP5_I2CDAI      (1U << 29)
#define FP5_I2CDAO      (1U << 30)
#define FP5_I2CCLO      (1U << 31)
#define FP6_LOCK  0xFFFFFFFFU

#define fp7_mcpassno (037777777U << 9)
#define fp7_mcpltrow (7U << 6)
#define fp7_mcpswrow (3U << 4)
#define fp7_mcpstate (017U << 0)

#define fp8_lbMS3    (1U << 31)
#define fp8_lbMS0    (1U << 30)
#define fp8_lbFET    (1U << 29)
#define fp8_lbEXE    (1U << 28)
#define fp8_lbDEF    (1U << 27)
#define fp8_lbWCT    (1U << 26)
#define fp8_lbCAD    (1U << 25)
#define fp8_lbBRK    (1U << 24)
#define fp8_lbMA (07777U << 12)
#define fp8_lbPC (07777U <<  0)

#define fp9_lbAND    (1U << 31)
#define fp9_lbTAD    (1U << 30)
#define fp9_lbISZ    (1U << 29)
#define fp9_lbDCA    (1U << 28)
#define fp9_lbJMS    (1U << 27)
#define fp9_lbJMP    (1U << 26)
#define fp9_lbIOT    (1U << 25)
#define fp9_lbOPR    (1U << 24)
#define fp9_lbAC (07777U << 12)
#define fp9_lbMB (07777U <<  0)

#define fp10_lbDF     (7U << 29)
#define fp10_lbIF     (7U << 26)
#define fp10_lbLINK   (1U << 25)
#define fp10_lbMS   (017U << 20)
#define fp10_lbION    (1U << 19)
#define fp10_lbPAU    (1U << 18)
#define fp10_lbRUN    (1U << 17)
#define fp10_lbSC   (037U << 12)
#define fp10_lbMQ (07777U <<  0)

#define fp11_swSTART  (1U << 25)
#define fp11_swLDAD   (1U << 24)
#define fp11_swDEPOS  (1U << 23)
#define fp11_swEXAM   (1U << 22)
#define fp11_swCONT   (1U << 21)
#define fp11_swSTOP   (1U << 20)
#define fp11_swSSTEP  (1U << 19)
#define fp11_swSINST  (1U << 18)
#define fp11_swDFLD   (7U << 15)
#define fp11_swIFLD   (7U << 12)
#define fp11_swSR (07777U <<  0)

#define fp12_dbncount  (0x3FU << 26)

#define fp13_dbnlimit  (0x3FU << 26)
#define fp13_ltspeed (0xFFFFU << 10)
#define fp13_i2cspeed (0x3FFU <<  0)

#endif
