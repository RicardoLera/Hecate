  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity vivado_tb_3x3x3 is
  port (
    clock, reset : in  std_logic;
    read_slice   : in std_logic;
    serial_slice : in  t_signed;
    serial_res   : out t_signed; -- Total output size is (66+3−1)×(66+3−1)×(3+3−1)×32×64 = 47349760 bits
    serial_ready : out std_logic
  );
end entity vivado_tb_3x3x3;

architecture synth of vivado_tb_3x3x3 is

  component clk_wiz_mmcm
    port (
      reset        : in  std_logic;
      locked       : out std_logic;
      clk_in       : in  std_logic;
      clk_out_100m : out std_logic;
      clk_out_50m  : out std_logic;
      clk_out_25m  : out std_logic
     );
  end component;

  component blk_mem_gen_kernel_3x3x3
    port (
      clka  : in std_logic;
      ena   : in std_logic;
      addra : in std_logic_vector(2 downto 0);
      douta : out std_logic_vector(31 downto 0)
    );
  end component;

  component gtwizard_3x3x3 
    port (
      SYSCLK_IN                               : in   std_logic;
      SOFT_RESET_TX_IN                        : in   std_logic;
      SOFT_RESET_RX_IN                        : in   std_logic;
      DONT_RESET_ON_DATA_ERROR_IN             : in   std_logic;
      GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
      GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
      GT0_DATA_VALID_IN                       : in   std_logic;
      --_________________________________________________________________________
      --GT0  (X0Y4)
      --____________________________CHANNEL PORTS________________________________
      --------------------------------- CPLL Ports -------------------------------
      gt0_cpllfbclklost_out                   : out  std_logic;
      gt0_cplllock_out                        : out  std_logic;
      gt0_cplllockdetclk_in                   : in   std_logic;
      gt0_cpllreset_in                        : in   std_logic;
      -------------------------- Channel - Clocking Ports ------------------------
      gt0_gtrefclk0_in                        : in   std_logic;
      gt0_gtrefclk1_in                        : in   std_logic;
      ---------------------------- Channel - DRP Ports  --------------------------
      gt0_drpclk_in                           : in   std_logic;
      --------------------- RX Initialization and Reset Ports --------------------
      gt0_eyescanreset_in                     : in   std_logic;
      gt0_rxuserrdy_in                        : in   std_logic;
      -------------------------- RX Margin Analysis Ports ------------------------
      gt0_eyescandataerror_out                : out  std_logic;
      gt0_eyescantrigger_in                   : in   std_logic;
      ------------------- Receive Ports - Digital Monitor Ports ------------------
      gt0_dmonitorout_out                     : out  std_logic_vector(14 downto 0);
      ------------------ Receive Ports - FPGA RX Interface Ports -----------------
      gt0_rxusrclk_in                         : in   std_logic;
      gt0_rxusrclk2_in                        : in   std_logic;
      ------------------ Receive Ports - FPGA RX interface Ports -----------------
      gt0_rxdata_out                          : out  std_logic_vector(31 downto 0);
      ------------------------ Receive Ports - RX AFE Ports ----------------------
      gt0_gthrxn_in                           : in   std_logic;
      --------------------- Receive Ports - RX Equalizer Ports -------------------
      gt0_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
      gt0_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
      --------------- Receive Ports - RX Fabric Output Control Ports -------------
      gt0_rxoutclkfabric_out                  : out  std_logic;
      ------------- Receive Ports - RX Initialization and Reset Ports ------------
      gt0_gtrxreset_in                        : in   std_logic;
      ------------------------ Receive Ports -RX AFE Ports -----------------------
      gt0_gthrxp_in                           : in   std_logic;
      -------------- Receive Ports -RX Initialization and Reset Ports ------------
      gt0_rxresetdone_out                     : out  std_logic;
      --------------------- TX Initialization and Reset Ports --------------------
      gt0_gttxreset_in                        : in   std_logic;
      gt0_txuserrdy_in                        : in   std_logic;
      ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
      gt0_txusrclk_in                         : in   std_logic;
      gt0_txusrclk2_in                        : in   std_logic;
      ------------------ Transmit Ports - TX Data Path interface -----------------
      gt0_txdata_in                           : in   std_logic_vector(31 downto 0);
      ---------------- Transmit Ports - TX Driver and OOB signaling --------------
      gt0_gthtxn_out                          : out  std_logic;
      gt0_gthtxp_out                          : out  std_logic;
      ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
      gt0_txoutclk_out                        : out  std_logic;
      gt0_txoutclkfabric_out                  : out  std_logic;
      gt0_txoutclkpcs_out                     : out  std_logic;
      ------------- Transmit Ports - TX Initialization and Reset Ports -----------
      gt0_txresetdone_out                     : out  std_logic;
      --____________________________COMMON PORTS________________________________
      GT0_QPLLOUTCLK_IN                       : in   std_logic;
      GT0_QPLLOUTREFCLK_IN                    : in   std_logic
    );
  end component;

  signal mmcm_locked, mmcm_reset, clk_100m, clk_50m, clk_25m : std_logic;

  signal rom_k_addr           : std_logic_vector(15 downto 0);
  signal rom_k_out            : std_logic_vector(31 downto 0);
  signal rom_k_clk, rom_k_ena : std_logic;

  signal gt0_rxdata_out, gt0_txdata_in : std_logic_vector(31 downto 0);
  signal gt0_dmonitorout_out           : std_logic_vector(14 downto 0);
  signal gt0_rxmonitorout_out          : std_logic_vector( 6 downto 0);
  signal gt0_rxmonitorsel_in           : std_logic_vector( 1 downto 0);
  signal
    gt0_sysclk_in,
    gt0_soft_reset_tx_in,
    gt0_soft_reset_rx_in,
    gt0_dont_reset_on_data_error_in,
    gt0_tx_fsm_reset_done_out,
    gt0_rx_fsm_reset_done_out,
    gt0_data_valid_in,
    gt0_cpllfbclklost_out,
    gt0_cplllock_out,
    gt0_cplllockdetclk_in,
    gt0_cpllreset_in,
    gt0_gtrefclk0_in,
    gt0_gtrefclk1_in,
    gt0_drpclk_in,
    gt0_eyescanreset_in,
    gt0_rxuserrdy_in,
    gt0_eyescandataerror_out,
    gt0_eyescantrigger_in,
    gt0_rxusrclk_in,
    gt0_rxusrclk2_in,
    gt0_gthrxn_in,
    gt0_rxoutclkfabric_out,
    gt0_gtrxreset_in,
    gt0_gthrxp_in,
    gt0_rxresetdone_out,
    gt0_gttxreset_in,
    gt0_txuserrdy_in,
    gt0_txusrclk_in,
    gt0_txusrclk2_in,
    gt0_gthtxn_out,
    gt0_gthtxp_out,
    gt0_txoutclk_out,
    gt0_txoutclkfabric_out,
    gt0_txoutclkpcs_out,
    gt0_txresetdone_out,
    gt0_qplloutclk_in,
    gt0_qplloutrefclk_in
  : std_logic;

  -- signal slice, ker : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
  -- signal res        : t_signed_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
  -- signal oa_ready, oa_start, serial_s_ready, serial_k_ready, serial_res_ready, fetch_kernel : std_logic := '0';

begin

  gen_clocks : clk_wiz_mmcm
    port map (
      reset        => mmcm_reset,
      locked       => mmcm_locked,
      clk_in       => clock,
      clk_out_100m => clk_100m,
      clk_out_50m  => clk_50m,
      clk_out_25m  => clk_25m
    );

  gen_rom_k : blk_mem_gen_kernel_3x3x3
    port map (
      clka  => rom_k_clk,
      ena   => rom_k_ena,
      addra => rom_k_addr,
      douta => rom_k_out
    );

  gt0 : gtwizard_3x3x3
    port map (
      SYSCLK_IN                       =>      gt0_sysclk_in,                     
      SOFT_RESET_TX_IN                =>      gt0_soft_reset_tx_in,              
      SOFT_RESET_RX_IN                =>      gt0_soft_reset_rx_in,                  
      DONT_RESET_ON_DATA_ERROR_IN     =>      gt0_dont_reset_on_data_error_in,
      GT0_TX_FSM_RESET_DONE_OUT       =>      gt0_tx_fsm_reset_done_out,     
      GT0_RX_FSM_RESET_DONE_OUT       =>      gt0_rx_fsm_reset_done_out,       
      GT0_DATA_VALID_IN               =>      gt0_data_valid_in,               
      --_________________________________________________________________________
      --GT0  (X0Y4)
      --____________________________CHANNEL PORTS________________________________
      --------------------------------- CPLL Ports -------------------------------
      gt0_cpllfbclklost_out           =>      gt0_cpllfbclklost_out,
      gt0_cplllock_out                =>      gt0_cplllock_out,
      gt0_cplllockdetclk_in           =>      gt0_cplllockdetclk_in,
      gt0_cpllreset_in                =>      gt0_cpllreset_in,
      -------------------------- Channel - Clocking Ports ------------------------
      gt0_gtrefclk0_in                =>      gt0_gtrefclk0_in,
      gt0_gtrefclk1_in                =>      gt0_gtrefclk1_in,
      ---------------------------- Channel - DRP Ports  --------------------------
      gt0_drpclk_in                   =>      gt0_drpclk_in,
      --------------------- RX Initialization and Reset Ports --------------------
      gt0_eyescanreset_in             =>      gt0_eyescanreset_in,
      gt0_rxuserrdy_in                =>      gt0_rxuserrdy_in,
      -------------------------- RX Margin Analysis Ports ------------------------
      gt0_eyescandataerror_out        =>      gt0_eyescandataerror_out,
      gt0_eyescantrigger_in           =>      gt0_eyescantrigger_in,
      ------------------- Receive Ports - Digital Monitor Ports ------------------
      gt0_dmonitorout_out             =>      gt0_dmonitorout_out,
      ------------------ Receive Ports - FPGA RX Interface Ports -----------------
      gt0_rxusrclk_in                 =>      gt0_rxusrclk_in,
      gt0_rxusrclk2_in                =>      gt0_rxusrclk2_in,
      ----------------- Receive Ports - FPGA RX interface Ports -----------------
      gt0_rxdata_out                  =>      gt0_rxdata_out,
      ------------------------ Receive Ports - RX AFE Ports ----------------------
      gt0_gthrxn_in                   =>      gt0_gthrxn_in,
      --------------------- Receive Ports - RX Equalizer Ports -------------------
      gt0_rxmonitorout_out            =>      gt0_rxmonitorout_out,
      gt0_rxmonitorsel_in             =>      gt0_rxmonitorsel_in,
      --------------- Receive Ports - RX Fabric Output Control Ports -------------
      gt0_rxoutclkfabric_out          =>      gt0_rxoutclkfabric_out,
      ------------- Receive Ports - RX Initialization and Reset Ports ------------
      gt0_gtrxreset_in                =>      gt0_gtrxreset_in,
      ------------------------ Receive Ports -RX AFE Ports -----------------------
      gt0_gthrxp_in                   =>      gt0_gthrxp_in,
      -------------- Receive Ports -RX Initialization and Reset Ports ------------
      gt0_rxresetdone_out             =>      gt0_rxresetdone_out,
      --------------------- TX Initialization and Reset Ports --------------------
      gt0_gttxreset_in                =>      gt0_gttxreset_in,
      gt0_txuserrdy_in                =>      gt0_txuserrdy_in,
      ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
      gt0_txusrclk_in                 =>      gt0_txusrclk_in,
      gt0_txusrclk2_in                =>      gt0_txusrclk2_in,
      ------------------ Transmit Ports - TX Data Path interface -----------------
      gt0_txdata_in                   =>      gt0_txdata_in,
      ---------------- Transmit Ports - TX Driver and OOB signaling --------------
      gt0_gthtxn_out                  =>      gt0_gthtxn_out,
      gt0_gthtxp_out                  =>      gt0_gthtxp_out,
      ---------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
      gt0_txoutclk_out                =>      gt0_txoutclk_out,
      gt0_txoutclkfabric_out          =>      gt0_txoutclkfabric_out,
      gt0_txoutclkpcs_out             =>      gt0_txoutclkpcs_out,
      ------------- Transmit Ports - TX Initialization and Reset Ports -----------
      gt0_txresetdone_out             =>      gt0_txresetdone_out,
      --____________________________COMMON PORTS________________________________
      GT0_QPLLOUTCLK_IN               =>      gt0_qplloutclk_in,  
      GT0_QPLLOUTREFCLK_IN            =>      gt0_qplloutrefclk_in 
    );




















  dut : component hecate
    port map (
      img   => img,
      ker   => ker,
      clock => clk_100m,
      reset => reset,
      start => oa_start,
      res   => res,
      ready => oa_ready
    );



















  -- fetch slice
  serial_s : process (clk_100m) is
    variable zi, yi, xi, n : natural := 0;
  begin
    if rising_edge(clk_100m) then
      if fetch_kernel and locked then
        slice(zi)(yi)(xi) <= signed(serial_img);
        xi := xi + 1;
        if (xi = kx) then yi := yi + 1; xi := 0; end if;
        if (yi = ky) then zi := zi + 1; yi := 0; end if;
        if (zi = kz) then serial_k_ready <= '1'; end if;
        rom_k_addr <= std_logic_vector(to_unsigned(xi + yi*kx + zi*ky*kx, 3));
      else
        n := 0; zi := 0; yi := 0; xi := 0;
        serial_k_ready <= '0';
      end if;
    end if;
  end process serial_s;

  -- fetch kernel
  serial_k : process (clk_100m) is
    variable zi, yi, xi, n : natural := 0;
  begin
    if rising_edge(clk_100m) then
      if fetch_kernel and locked then
        ker(zi)(yi)(xi) <= signed(rom_k_out);
        xi := xi + 1;
        if (xi = kx) then yi := yi + 1; xi := 0; end if;
        if (yi = ky) then zi := zi + 1; yi := 0; end if;
        if (zi = kz) then serial_k_ready <= '1'; end if;
        rom_k_addr <= std_logic_vector(to_unsigned(xi + yi*kx + zi*ky*kx, 3));
      else
        n := 0; zi := 0; yi := 0; xi := 0;
        serial_k_ready <= '0';
      end if;
    end if;
  end process serial_k;
  oa_start <= serial_s_ready and serial_k_ready;

  -- output
  serial_out : process (clk_100m) is
    variable ozi, oyi, oxi : natural := 0;
  begin
    if rising_edge(clk_100m) then
      if reset then
        ozi := 0; oyi := 0; oxi := 0;
        ready <= '0';
      elsif (start and oa_ready and not ready) then
        ram_serial <= res(ozi)(oyi)(oxi);
        oxi := oxi + 1;
        if (oxi = ox) then oyi := oyi + 1; oxi := 0; end if;
        if (oyi = oy) then ozi := ozi + 1; oyi := 0; end if;
        if (ozi = oz) then ready <= '1'; end if;
      end if;
    end if;
  end process serial_out;

end architecture synth;