#ifndef _ZDEFS_H
#define _ZDEFS_H

#define Z_RA 1
#define i3CYCLE_M (1U<<2)
#define i3CYCLE_I Z_RA
#define iACCLEAR_M (1U<<3)
#define iACCLEAR_I Z_RA
#define iBRKRQST_M (1U<<4)
#define iBRKRQST_I Z_RA
#define iBRKWRM_M (1U<<5)
#define iBRKWRM_I Z_RA
#define iCAINC_M (1U<<6)
#define iCAINC_I Z_RA
#define iINTRQST_M (1U<<7)
#define iINTRQST_I Z_RA
#define iIOSKIP_M (1U<<8)
#define iIOSKIP_I Z_RA
#define iLNKTOG_M (1U<<9)
#define iLNKTOG_I Z_RA
#define iPAUSE_M (1U<<10)
#define iPAUSE_I Z_RA
#define memdisab_M (1U<<11)
#define memdisab_I Z_RA
#define reset_M (1U<<1)
#define reset_I Z_RA
#define zclock_M (1U<<12)
#define zclock_I Z_RA
#define zreset_M (1U<<13)
#define zreset_I Z_RA

#define Z_RB 2
#define iDMAADDR_M (077777U<<0)
#define iDMAADDR_I Z_RB
#define iINBUS_M (07777U<<15)
#define iINBUS_I Z_RB

#define Z_RC 3
#define oBREAK_M (1U<<0)
#define oBREAK_I Z_RC
#define oBUSINI_M (1U<<1)
#define oBUSINI_I Z_RC
#define oBWCOV_M (1U<<2)
#define oBWCOV_I Z_RC
#define oIOP_M (1U<<3)
#define oIOP_I Z_RC
#define oLINK_M (1U<<4)
#define oLINK_I Z_RC
#define oRUN_M (1U<<5)
#define oRUN_I Z_RC
#define oTP1_M (1U<<6)
#define oTP1_I Z_RC
#define oTP2_M (1U<<7)
#define oTP2_I Z_RC
#define oTP3_M (1U<<8)
#define oTP3_I Z_RC
#define oTP4_M (1U<<9)
#define oTP4_I Z_RC
#define oTS1_M (1U<<10)
#define oTS1_I Z_RC
#define oTS2_M (1U<<11)
#define oTS2_I Z_RC
#define oTS3_M (1U<<12)
#define oTS3_I Z_RC
#define oTS4_M (1U<<13)
#define oTS4_I Z_RC
#define swstart_M (1U<<14)
#define swstart_I Z_RC
#define swldad_M (1U<<15)
#define swldad_I Z_RC
#define swdepos_M (1U<<16)
#define swdepos_I Z_RC
#define swexam_M (1U<<17)
#define swexam_I Z_RC
#define swcont_M (1U<<18)
#define swcont_I Z_RC
#define swstop_M (1U<<19)
#define swstop_I Z_RC
#define swsstep_M (1U<<20)
#define swsstep_I Z_RC
#define swsinst_M (1U<<21)
#define swsinst_I Z_RC
#define oION_M (1U<<22)
#define oION_I Z_RC
#define clok2_M (1U<<23)
#define clok2_I Z_RC

#define Z_RD 4
#define memfield_M (7U<<0)
#define memfield_I Z_RD
#define majst_M (017U<<3)
#define majst_I Z_RD
#define sctr_M (037U<<7)
#define sctr_I Z_RD
#define swdfld_M (017U<<24)
#define swdfld_I Z_RD
#define swifld_M (7U<<27)
#define swifld_I Z_RD

#define Z_RE 5
#define oMADR_M (07777U<<0)
#define oMADR_I Z_RE
#define oMBUF_M (07777U<<12)
#define oMBUF_I Z_RE

#define Z_RF 6
#define oACUM_M (07777U<<0)
#define oACUM_I Z_RF
#define mquo_M (07777U<<12)
#define mquo_I Z_RF

#define Z_RG 7
#define pctr_M (07777U<<0)
#define pctr_I Z_RG
#define businbus_M (07777U<<12)
#define businbus_I Z_RG
#define busacclr_M (1U<<24)
#define busacclr_I Z_RG
#define busintrq_M (1U<<25)
#define busintrq_I Z_RG
#define busioskp_M (1U<<26)
#define busioskp_I Z_RG

#define Z_RH 8  // gpin
#define Z_RI 9  // gpout

#endif
