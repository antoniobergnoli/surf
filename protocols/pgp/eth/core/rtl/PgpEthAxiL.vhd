-------------------------------------------------------------------------------
-- File       : Pgp2bAxi.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- AXI-Lite block to manage the PGP_ETH interface.
--
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.PgpEthPkg.all;

entity PgpEthAxiL is
   generic (
      TPD_G            : time                  := 1 ns;
      WRITE_EN_G       : boolean               := false;  -- Set to false when on remote end of a link
      AXIL_BASE_ADDR_G : slv(31 downto 0)      := (others => '0');
      AXIL_CLK_FREQ_G  : real                  := 156.25E+6;
      LOOPBACK_G       : slv(2 downto 0)       := (others => '0');
      RX_POLARITY_G    : slv(9 downto 0)       := (others => '0');
      TX_POLARITY_G    : slv(9 downto 0)       := (others => '0');
      TX_DIFF_CTRL_G   : Slv5Array(9 downto 0) := (others => "11000");
      TX_PRE_CURSOR_G  : Slv5Array(9 downto 0) := (others => "00000");
      TX_POST_CURSOR_G : Slv5Array(9 downto 0) := (others => "00000"));
   port (
      -- Clock and Reset
      pgpClk          : in  sl;
      pgpRst          : in  sl;
      -- Tx User interface (pgpClk domain)
      pgpTxIn         : out PgpEthTxInType;
      pgpTxOut        : in  PgpEthTxOutType;
      locTxIn         : in  PgpEthTxInType := PGP_ETH_TX_IN_INIT_C;
      -- RX PGP Interface (pgpClk domain)
      pgpRxIn         : out PgpEthRxInType;
      pgpRxOut        : in  PgpEthRxOutType;
      locRxIn         : in  PgpEthRxInType := PGP_ETH_RX_IN_INIT_C;
      -- Ethernet Configuration
      remoteMac       : in  slv(47 downto 0);
      localMac        : in  slv(47 downto 0);
      broadcastMac    : out slv(47 downto 0);
      etherType       : out slv(15 downto 0);
      -- Misc Debug Interfaces
      loopback        : out slv(2 downto 0);
      rxPolarity      : out slv(9 downto 0);
      txPolarity      : out slv(9 downto 0);
      txDiffCtrl      : out Slv5Array(9 downto 0);
      txPreCursor     : out Slv5Array(9 downto 0);
      txPostCursor    : out Slv5Array(9 downto 0);
      -- AXI-Lite Register Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end PgpEthAxiL;

architecture rtl of PgpEthAxiL is

   constant NUM_AXIL_MASTERS_C : positive := 2;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, AXIL_BASE_ADDR_G, 10, 8);

   constant STATUS_SIZE_C      : positive := 61;
   constant STATUS_CNT_WIDTH_C : positive := 12;

   type RegType is record
      cntRst         : sl;
      rollOverEn     : slv(63 downto 0);
      broadcastMac   : slv(47 downto 0);
      etherType      : slv(15 downto 0);
      loopback       : slv(2 downto 0);
      rxPolarity     : slv(9 downto 0);
      txPolarity     : slv(9 downto 0);
      txDiffCtrl     : Slv5Array(9 downto 0);
      txPreCursor    : Slv5Array(9 downto 0);
      txPostCursor   : Slv5Array(9 downto 0);
      pgpTxIn        : PgpEthTxInType;
      pgpRxIn        : PgpEthRxInType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
   end record RegType;
   constant REG_INIT_C : RegType := (
      cntRst         => '0',
      rollOverEn     => x"0C05_0000_FFFF_FFFF",
      broadcastMac   => x"FF_FF_FF_FF_FF_FF",
      etherType      => x"11_01",       -- EtherType = 0x0111 ("Experimental")
      loopBack       => LOOPBACK_G,
      rxPolarity     => RX_POLARITY_G,
      txPolarity     => TX_POLARITY_G,
      txDiffCtrl     => TX_DIFF_CTRL_G,
      txPreCursor    => TX_PRE_CURSOR_G,
      txPostCursor   => TX_POST_CURSOR_G,
      pgpTxIn        => PGP_ETH_TX_IN_INIT_C,
      pgpRxIn        => PGP_ETH_RX_IN_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal freqMeasured : slv(31 downto 0);

   signal frameTxMinSize : slv(15 downto 0);
   signal frameTxMaxSize : slv(15 downto 0);

   signal frameRxMinSize : slv(15 downto 0);
   signal frameRxMaxSize : slv(15 downto 0);

   signal statusOut : slv(STATUS_SIZE_C-1 downto 0);

   signal syncTxIn : PgpEthTxInType;

begin

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_SyncStatusVector : entity work.AxiLiteRamSyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         CNT_RST_EDGE_G => true,
         CNT_WIDTH_G    => STATUS_CNT_WIDTH_C,
         WIDTH_G        => STATUS_SIZE_C)
      port map (
         -- Input Status bit Signals (wrClk domain)
         wrClk                  => pgpClk,
         statusIn(60)           => pgpRst,
         statusIn(59)           => pgpRxOut.opCodeEn,
         statusIn(58)           => pgpTxOut.opCodeReady,
         statusIn(57)           => pgpRxOut.remRxLinkReady,
         statusIn(56)           => pgpRxOut.linkDown,
         statusIn(55)           => pgpRxOut.linkReady,
         statusIn(54)           => pgpTxOut.linkReady,
         statusIn(53)           => pgpRxOut.phyRxActive,
         statusIn(52)           => pgpTxOut.phyTxActive,
         statusIn(51)           => pgpRxOut.frameRxErr,
         statusIn(50)           => pgpRxOut.frameRx,
         statusIn(49)           => pgpTxOut.frameTxErr,
         statusIn(48)           => pgpTxOut.frameTx,
         statusIn(47 downto 32) => pgpTxOut.locOverflow,
         statusIn(31 downto 16) => pgpTxOut.locPause,
         statusIn(15 downto 0)  => pgpRxOut.remRxPause,
         -- Outbound Status/control Signals (axilClk domain)  
         statusOut              => statusOut,
         cntRstIn               => r.cntRst,
         rollOverEnIn           => r.rollOverEn(STATUS_SIZE_C-1 downto 0),
         -- AXI-Lite Interface
         axilClk                => axilClk,
         axilRst                => axilRst,
         axilReadMaster         => axilReadMasters(0),
         axilReadSlave          => axilReadSlaves(0),
         axilWriteMaster        => axilWriteMasters(0),
         axilWriteSlave         => axilWriteSlaves(0));

   U_ClockFreq : entity work.SyncClockFreq
      generic map (
         TPD_G          => TPD_G,
         REF_CLK_FREQ_G => AXIL_CLK_FREQ_G,
         CNT_WIDTH_G    => 32)
      port map (
         freqOut => freqMeasured,
         -- Clocks
         clkIn   => pgpClk,
         locClk  => axilClk,
         refClk  => axilClk);

   U_frameTxSize : entity work.SyncMinMax
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         -- Write Interface (wrClk domain)
         wrClk   => pgpClk,
         wrRst   => pgpRst,
         wrEn    => pgpTxOut.frameTx,
         dataIn  => pgpTxOut.frameTxSize,
         -- Read Interface (rdClk domain)
         rdClk   => axilClk,
         rstStat => r.cntRst,
         dataMin => frameTxMinSize,
         dataMax => frameTxMaxSize);

   U_frameRxSize : entity work.SyncMinMax
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         -- Write Interface (wrClk domain)
         wrClk   => pgpClk,
         wrRst   => pgpRst,
         wrEn    => pgpRxOut.frameRx,
         dataIn  => pgpRxOut.frameRxSize,
         -- Read Interface (rdClk domain)
         rdClk   => axilClk,
         rstStat => r.cntRst,
         dataMin => frameRxMinSize,
         dataMax => frameRxMaxSize);

   process (axilReadMasters, axilRst, axilWriteMasters, frameRxMaxSize,
            frameRxMinSize, frameTxMaxSize, frameTxMinSize, freqMeasured,
            localMac, r, remoteMac, statusOut) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobes
      v.cntRst := '0';

      ---------------------------------
      -- Determine the transaction type
      ---------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMasters(1), axilReadMasters(1), v.axilWriteSlave, v.axilReadSlave);

      -------------------------
      -- Map the read registers
      -------------------------
      
      axiSlaveRegisterR(axilEp, x"00", 0, statusOut);     
      axiSlaveRegisterR(axilEp, x"10", 0, freqMeasured);

      axiSlaveRegisterR(axilEp, x"14", 0, frameTxMinSize);
      axiSlaveRegisterR(axilEp, x"14", 16, frameTxMaxSize);

      axiSlaveRegisterR(axilEp, x"18", 0, frameRxMinSize);
      axiSlaveRegisterR(axilEp, x"18", 16, frameRxMaxSize);

      if (WRITE_EN_G) then

         axiSlaveRegister(axilEp, x"30", 0, v.loopback);
         axiSlaveRegister(axilEp, x"30", 8, v.pgpTxIn.disable);
         axiSlaveRegister(axilEp, x"30", 9, v.pgpTxIn.flowCntlDis);
         axiSlaveRegister(axilEp, x"30", 10, v.pgpRxIn.resetRx);

         axiSlaveRegister(axilEp, x"38", 0, v.rxPolarity);
         axiSlaveRegister(axilEp, x"38", 16, v.txPolarity);
         axiSlaveRegister(axilEp, x"3C", 0, v.pgpTxIn.nullInterval);

         for i in 9 downto 0 loop
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 8), 0, v.txDiffCtrl(i));
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 8), 8, v.txPreCursor(i));
            axiSlaveRegister(axilEp, toSlv(64+(4*i), 8), 16, v.txPostCursor(i));
         end loop;

         axiSlaveRegister(axilEp, x"D0", 0, v.broadcastMac);
         axiSlaveRegister(axilEp, x"D8", 0, v.etherType);

      else

         axiSlaveRegisterR(axilEp, x"30", 0, r.loopback);
         axiSlaveRegisterR(axilEp, x"30", 8, r.pgpTxIn.disable);
         axiSlaveRegisterR(axilEp, x"30", 9, r.pgpTxIn.flowCntlDis);
         axiSlaveRegisterR(axilEp, x"30", 10, r.pgpRxIn.resetRx);

         axiSlaveRegisterR(axilEp, x"38", 0, r.rxPolarity);
         axiSlaveRegisterR(axilEp, x"38", 16, r.txPolarity);
         axiSlaveRegisterR(axilEp, x"3C", 0, r.pgpTxIn.nullInterval);

         for i in 9 downto 0 loop
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 8), 0, r.txDiffCtrl(i));
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 8), 8, r.txPreCursor(i));
            axiSlaveRegisterR(axilEp, toSlv(64+(4*i), 8), 16, r.txPostCursor(i));
         end loop;

         axiSlaveRegisterR(axilEp, x"D0", 0, r.broadcastMac);
         axiSlaveRegisterR(axilEp, x"D8", 0, r.etherType);

      end if;

      axiSlaveRegisterR(axilEp, x"C0", 0, localMac);
      axiSlaveRegisterR(axilEp, x"C8", 0, remoteMac);

      axiSlaveRegister(axilEp, x"F0", 0, v.rollOverEn);
      axiSlaveRegister(axilEp, x"FC", 0, v.cntRst);

      -------------------------------------
      -- Close out the AXI-Lite transaction
      -------------------------------------
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Next register assignment
      rin <= v;

      -- Outputs
      axilReadSlaves(1)  <= r.axilReadSlave;
      axilWriteSlaves(1) <= r.axilWriteSlave;
      loopback           <= r.loopback;
      rxPolarity         <= r.rxPolarity;
      txPolarity         <= r.txPolarity;
      txDiffCtrl         <= r.txDiffCtrl;
      txPreCursor        <= r.txPreCursor;
      txPostCursor       <= r.txPostCursor;

   end process;

   process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process;

   U_etherType : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 16)
      port map (
         clk     => pgpClk,
         dataIn  => r.etherType,
         dataOut => etherType);

   U_broadcastMac : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 48)
      port map (
         clk     => pgpClk,
         dataIn  => r.broadcastMac,
         dataOut => broadcastMac);

   U_nullInterval : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 32)
      port map (
         clk     => pgpClk,
         dataIn  => r.pgpTxIn.nullInterval,
         dataOut => syncTxIn.nullInterval);

   U_SyncBits : entity work.SynchronizerVector
      generic map(
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         clk        => pgpClk,
         -- Inputs
         dataIn(0)  => r.pgpTxIn.disable,
         dataIn(1)  => r.pgpTxIn.flowCntlDis,
         -- Outputs
         dataOut(0) => syncTxIn.disable,
         dataOut(1) => syncTxIn.flowCntlDis);

   pgpTxIn.disable      <= locTxIn.disable or syncTxIn.disable;
   pgpTxIn.flowCntlDis  <= locTxIn.flowCntlDis or syncTxIn.flowCntlDis;
   pgpTxIn.nullInterval <= syncTxIn.nullInterval;
   pgpTxIn.opCodeEn     <= locTxIn.opCodeEn;
   pgpTxIn.opCode       <= locTxIn.opCode;
   pgpTxIn.locData      <= locTxIn.locData;
   pgpRxIn.resetRx      <= locRxIn.resetRx or r.pgpRxIn.resetRx;

end rtl;
