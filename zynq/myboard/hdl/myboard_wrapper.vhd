--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
--Date        : Sun May 24 15:46:38 2026
--Host        : homepc2 running 64-bit Ubuntu 16.04.7 LTS
--Command     : generate_target myboard_wrapper.bd
--Design      : myboard_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity myboard_wrapper is
  port (
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    LEDoutB_0 : out STD_LOGIC;
    LEDoutG_0 : out STD_LOGIC;
    LEDoutR_0 : out STD_LOGIC;
    bFPI2CDATA_0 : inout STD_LOGIC;
    bFPI2CLOCK_0 : inout STD_LOGIC;
    hdw_iACCLEAR_0 : out STD_LOGIC;
    hdw_iBRKGNTO_0 : out STD_LOGIC;
    hdw_iBRKRQST_0 : out STD_LOGIC;
    hdw_iBRKWRM_0 : out STD_LOGIC;
    hdw_iCAINC_0 : out STD_LOGIC;
    hdw_iCYCLE3_0 : out STD_LOGIC;
    hdw_iDMAFLD_0 : out STD_LOGIC_VECTOR ( 2 downto 0 );
    hdw_iINBUS_0 : out STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_iINTRQST_0 : out STD_LOGIC;
    hdw_iIOSKIP_0 : out STD_LOGIC;
    hdw_iPAUSE_0 : out STD_LOGIC;
    hdw_oACUM_0 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_oBRKCYC_0 : in STD_LOGIC;
    hdw_oBRKGNTI_0 : in STD_LOGIC;
    hdw_oBRKRQST_0 : in STD_LOGIC;
    hdw_oBUSINI_0 : in STD_LOGIC;
    hdw_oBWCOV_0 : in STD_LOGIC;
    hdw_oCLOCK_0 : in STD_LOGIC;
    hdw_oIOP_0 : in STD_LOGIC;
    hdw_oMBUF_0 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_oRESET_0 : in STD_LOGIC;
    hdw_oTP1_0 : in STD_LOGIC;
    hdw_oTP2_0 : in STD_LOGIC;
    hdw_oTP3_0 : in STD_LOGIC;
    hdw_oTP4_0 : in STD_LOGIC;
    hdw_oTS1_0 : in STD_LOGIC;
    hdw_oTS2_0 : in STD_LOGIC;
    hdw_oTS3_0 : in STD_LOGIC;
    hdw_oTS4_0 : in STD_LOGIC;
    iFPI2CDDIR_0 : out STD_LOGIC;
    i_FPI2CDENA_0 : out STD_LOGIC;
    yclock_0 : in STD_LOGIC;
    zclock_0 : in STD_LOGIC;
    zreset_0 : in STD_LOGIC
  );
end myboard_wrapper;

architecture STRUCTURE of myboard_wrapper is
  component myboard is
  port (
    LEDoutB_0 : out STD_LOGIC;
    LEDoutG_0 : out STD_LOGIC;
    LEDoutR_0 : out STD_LOGIC;
    bFPI2CDATA_0 : inout STD_LOGIC;
    bFPI2CLOCK_0 : inout STD_LOGIC;
    iFPI2CDDIR_0 : out STD_LOGIC;
    i_FPI2CDENA_0 : out STD_LOGIC;
    DDR_cas_n : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    hdw_iACCLEAR_0 : out STD_LOGIC;
    hdw_iBRKGNTO_0 : out STD_LOGIC;
    hdw_iBRKRQST_0 : out STD_LOGIC;
    hdw_iBRKWRM_0 : out STD_LOGIC;
    hdw_iCAINC_0 : out STD_LOGIC;
    hdw_iCYCLE3_0 : out STD_LOGIC;
    hdw_iDMAFLD_0 : out STD_LOGIC_VECTOR ( 2 downto 0 );
    hdw_iINBUS_0 : out STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_iINTRQST_0 : out STD_LOGIC;
    hdw_iIOSKIP_0 : out STD_LOGIC;
    hdw_iPAUSE_0 : out STD_LOGIC;
    yclock_0 : in STD_LOGIC;
    zclock_0 : in STD_LOGIC;
    zreset_0 : in STD_LOGIC;
    hdw_oACUM_0 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_oBRKCYC_0 : in STD_LOGIC;
    hdw_oBRKGNTI_0 : in STD_LOGIC;
    hdw_oBRKRQST_0 : in STD_LOGIC;
    hdw_oBUSINI_0 : in STD_LOGIC;
    hdw_oBWCOV_0 : in STD_LOGIC;
    hdw_oCLOCK_0 : in STD_LOGIC;
    hdw_oIOP_0 : in STD_LOGIC;
    hdw_oMBUF_0 : in STD_LOGIC_VECTOR ( 11 downto 0 );
    hdw_oRESET_0 : in STD_LOGIC;
    hdw_oTP1_0 : in STD_LOGIC;
    hdw_oTP2_0 : in STD_LOGIC;
    hdw_oTP3_0 : in STD_LOGIC;
    hdw_oTP4_0 : in STD_LOGIC;
    hdw_oTS1_0 : in STD_LOGIC;
    hdw_oTS2_0 : in STD_LOGIC;
    hdw_oTS3_0 : in STD_LOGIC;
    hdw_oTS4_0 : in STD_LOGIC
  );
  end component myboard;
begin
myboard_i: component myboard
     port map (
      DDR_addr(14 downto 0) => DDR_addr(14 downto 0),
      DDR_ba(2 downto 0) => DDR_ba(2 downto 0),
      DDR_cas_n => DDR_cas_n,
      DDR_ck_n => DDR_ck_n,
      DDR_ck_p => DDR_ck_p,
      DDR_cke => DDR_cke,
      DDR_cs_n => DDR_cs_n,
      DDR_dm(3 downto 0) => DDR_dm(3 downto 0),
      DDR_dq(31 downto 0) => DDR_dq(31 downto 0),
      DDR_dqs_n(3 downto 0) => DDR_dqs_n(3 downto 0),
      DDR_dqs_p(3 downto 0) => DDR_dqs_p(3 downto 0),
      DDR_odt => DDR_odt,
      DDR_ras_n => DDR_ras_n,
      DDR_reset_n => DDR_reset_n,
      DDR_we_n => DDR_we_n,
      FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
      FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
      FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
      FIXED_IO_ps_clk => FIXED_IO_ps_clk,
      FIXED_IO_ps_porb => FIXED_IO_ps_porb,
      FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
      LEDoutB_0 => LEDoutB_0,
      LEDoutG_0 => LEDoutG_0,
      LEDoutR_0 => LEDoutR_0,
      bFPI2CDATA_0 => bFPI2CDATA_0,
      bFPI2CLOCK_0 => bFPI2CLOCK_0,
      hdw_iACCLEAR_0 => hdw_iACCLEAR_0,
      hdw_iBRKGNTO_0 => hdw_iBRKGNTO_0,
      hdw_iBRKRQST_0 => hdw_iBRKRQST_0,
      hdw_iBRKWRM_0 => hdw_iBRKWRM_0,
      hdw_iCAINC_0 => hdw_iCAINC_0,
      hdw_iCYCLE3_0 => hdw_iCYCLE3_0,
      hdw_iDMAFLD_0(2 downto 0) => hdw_iDMAFLD_0(2 downto 0),
      hdw_iINBUS_0(11 downto 0) => hdw_iINBUS_0(11 downto 0),
      hdw_iINTRQST_0 => hdw_iINTRQST_0,
      hdw_iIOSKIP_0 => hdw_iIOSKIP_0,
      hdw_iPAUSE_0 => hdw_iPAUSE_0,
      hdw_oACUM_0(11 downto 0) => hdw_oACUM_0(11 downto 0),
      hdw_oBRKCYC_0 => hdw_oBRKCYC_0,
      hdw_oBRKGNTI_0 => hdw_oBRKGNTI_0,
      hdw_oBRKRQST_0 => hdw_oBRKRQST_0,
      hdw_oBUSINI_0 => hdw_oBUSINI_0,
      hdw_oBWCOV_0 => hdw_oBWCOV_0,
      hdw_oCLOCK_0 => hdw_oCLOCK_0,
      hdw_oIOP_0 => hdw_oIOP_0,
      hdw_oMBUF_0(11 downto 0) => hdw_oMBUF_0(11 downto 0),
      hdw_oRESET_0 => hdw_oRESET_0,
      hdw_oTP1_0 => hdw_oTP1_0,
      hdw_oTP2_0 => hdw_oTP2_0,
      hdw_oTP3_0 => hdw_oTP3_0,
      hdw_oTP4_0 => hdw_oTP4_0,
      hdw_oTS1_0 => hdw_oTS1_0,
      hdw_oTS2_0 => hdw_oTS2_0,
      hdw_oTS3_0 => hdw_oTS3_0,
      hdw_oTS4_0 => hdw_oTS4_0,
      iFPI2CDDIR_0 => iFPI2CDDIR_0,
      i_FPI2CDENA_0 => i_FPI2CDENA_0,
      yclock_0 => yclock_0,
      zclock_0 => zclock_0,
      zreset_0 => zreset_0
    );
end STRUCTURE;
