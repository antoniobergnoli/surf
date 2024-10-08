-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: FIFO Wrapper
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
use ieee.numeric_std.all;


library surf;
use surf.StdRtlPkg.all;

entity Fifo is
   -- SYNTH_MODE_G Options: {"inferred", "xpm", "altera_mf"}
   -- MEMORY_TYPE_G: Xilinx Options: {"auto", "block", "distributed", "ultra"}
   -- MEMORY_TYPE_G: Altera Options: {"auto", "MLAB", "M20K" and "M144K"}
   generic (
      TPD_G           : time                       := 1 ns;
      RST_POLARITY_G  : sl                         := '1';  -- '1' for active high rst, '0' for active low
      RST_ASYNC_G     : boolean                    := false;
      GEN_SYNC_FIFO_G : boolean                    := false;
      FWFT_EN_G       : boolean                    := false;
      SYNTH_MODE_G    : string                     := "inferred";
      MEMORY_TYPE_G   : string                     := "block";
      SYNC_STAGES_G   : integer range 3 to (2**24) := 3;
      PIPE_STAGES_G   : natural range 0 to 16      := 0;
      DATA_WIDTH_G    : integer range 1 to (2**24) := 16;
      ADDR_WIDTH_G    : integer range 4 to 48      := 4;
      INIT_G          : slv                        := "0";
      FULL_THRES_G    : integer range 1 to (2**24) := 1;
      EMPTY_THRES_G   : integer range 1 to (2**24) := 1);
   port (
      -- Resets
      rst           : in  sl := not RST_POLARITY_G;
      --Write Ports (wr_clk domain)
      wr_clk        : in  sl;
      wr_en         : in  sl := '0';
      din           : in  slv(DATA_WIDTH_G-1 downto 0);
      wr_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      wr_ack        : out sl;
      overflow      : out sl;
      prog_full     : out sl;
      almost_full   : out sl;
      full          : out sl;
      not_full      : out sl;
      --Read Ports (rd_clk domain)
      rd_clk        : in  sl;           --unused if GEN_SYNC_FIFO_G = true
      rd_en         : in  sl := '0';
      dout          : out slv(DATA_WIDTH_G-1 downto 0);
      rd_data_count : out slv(ADDR_WIDTH_G-1 downto 0);
      valid         : out sl;
      underflow     : out sl;
      prog_empty    : out sl;
      almost_empty  : out sl;
      empty         : out sl);
end Fifo;

architecture rtl of Fifo is

   constant INIT_C   : slv(DATA_WIDTH_G-1 downto 0) := ite(INIT_G = "0", slvZero(DATA_WIDTH_G), INIT_G);
   signal data_count : slv(ADDR_WIDTH_G-1 downto 0) := (others => '0');

begin

   assert (INIT_G = "0" or INIT_G'length = DATA_WIDTH_G) report
      "INIT_G must either be ""0"" or the same length as DATA_WIDTH_G" severity failure;



   GEN_INFERRED : if (SYNTH_MODE_G = "inferred") generate

      FIFO_ASYNC_Gen : if (GEN_SYNC_FIFO_G = false) generate
         FifoAsync_Inst : entity surf.FifoAsync
            generic map (
               TPD_G          => TPD_G,
               RST_POLARITY_G => RST_POLARITY_G,
               MEMORY_TYPE_G  => MEMORY_TYPE_G,
               FWFT_EN_G      => FWFT_EN_G,
               SYNC_STAGES_G  => SYNC_STAGES_G,
               PIPE_STAGES_G  => PIPE_STAGES_G,
               DATA_WIDTH_G   => DATA_WIDTH_G,
               ADDR_WIDTH_G   => ADDR_WIDTH_G,
               INIT_G         => INIT_C,
               FULL_THRES_G   => FULL_THRES_G,
               EMPTY_THRES_G  => EMPTY_THRES_G)
            port map (
               rst           => rst,
               wr_clk        => wr_clk,
               wr_en         => wr_en,
               din           => din,
               wr_data_count => wr_data_count,
               wr_ack        => wr_ack,
               overflow      => overflow,
               prog_full     => prog_full,
               almost_full   => almost_full,
               full          => full,
               not_full      => not_full,
               rd_clk        => rd_clk,
               rd_en         => rd_en,
               dout          => dout,
               rd_data_count => rd_data_count,
               valid         => valid,
               underflow     => underflow,
               prog_empty    => prog_empty,
               almost_empty  => almost_empty,
               empty         => empty);
      end generate;

      FIFO_SYNC_Gen : if (GEN_SYNC_FIFO_G = true) generate
         wr_data_count <= data_count;
         rd_data_count <= data_count;

         FifoSync_Inst : entity surf.FifoSync
            generic map (
               TPD_G          => TPD_G,
               RST_POLARITY_G => RST_POLARITY_G,
               RST_ASYNC_G    => RST_ASYNC_G,
               MEMORY_TYPE_G  => MEMORY_TYPE_G,
               FWFT_EN_G      => FWFT_EN_G,
               PIPE_STAGES_G  => PIPE_STAGES_G,
               DATA_WIDTH_G   => DATA_WIDTH_G,
               ADDR_WIDTH_G   => ADDR_WIDTH_G,
               INIT_G         => INIT_C,
               FULL_THRES_G   => FULL_THRES_G,
               EMPTY_THRES_G  => EMPTY_THRES_G)
            port map (
               rst          => rst,
               clk          => wr_clk,
               wr_en        => wr_en,
               rd_en        => rd_en,
               din          => din,
               dout         => dout,
               data_count   => data_count,
               wr_ack       => wr_ack,
               valid        => valid,
               overflow     => overflow,
               underflow    => underflow,
               prog_full    => prog_full,
               prog_empty   => prog_empty,
               almost_full  => almost_full,
               almost_empty => almost_empty,
               full         => full,
               not_full     => not_full,
               empty        => empty);
      --NOTE:
      --    When mapping the FifoSync, I am assuming that
      --    wr_clk = rd_clk (both in frequency and in phase)
      --    and I only pass wr_clk into the FifoSync_Inst
      end generate;

   end generate;

end architecture rtl;
