  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity vivado_tb is
  port (
    clock, reset    : in  std_logic;
    read_slice      : in  std_logic;
    serial_in_img   : in  t_signed;
    serial_out_conv : out t_signed; -- Total output size is (66+3-1)×(66+3-1)×(3+3-1)×32×64 = 47349760 bits
    load_res, ready : out std_logic
  );
end entity vivado_tb;

architecture synth of vivado_tb is

  component clk_wiz_0
    port (
      reset        : in  std_logic;
      locked       : out std_logic;
      clk_in1      : in  std_logic;
      clk_out_100m : out std_logic;
      clk_out_50m  : out std_logic;
      clk_out_25m  : out std_logic
     );
  end component;

  signal mmcm_locked, clk_100m, clk_50m, clk_25m : std_logic;

  -- signal rom_k_addr : std_logic_vector(15 downto 0);
  -- signal rom_k_out  : std_logic_vector(31 downto 0);

  signal hec_slice : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
  signal ker       : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1) := kernel_f;
  signal hec_res   : t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
  signal hec_sxi, hec_syi, hec_szi : natural := 0;
  signal hec_reset, hec_start, hec_ker_ready, hec_acc_ready : std_logic := '0';

  signal state         : t_vivado_tb_state := initial;
  signal sxi, syi, szi : natural := 0;
  signal serial_in_rdy, img_complete, serial_out_rdy : std_logic := '0';

begin

  gen_clocks : clk_wiz_0
    port map (
      reset        => '0',
      locked       => mmcm_locked,
      clk_in1      => clock,
      clk_out_100m => clk_100m,
      clk_out_50m  => clk_50m,
      clk_out_25m  => clk_25m
    );

  -- gen_rom_k : blk_mem_gen_kernel_3x3x3
  --   port map (
  --     clka  => clk_100m,
  --     ena   => '1',
  --     addra => rom_k_addr,
  --     douta => rom_k_out
  --   );

  dut : hecate
    port map (
      slice     => hec_slice,
      ker       => ker,
      clock     => clk_25m,
      reset     => hec_reset,
      start     => hec_start,
      sxi       => hec_sxi,
      syi       => hec_syi,
      szi       => hec_szi,
      ker_ready => hec_ker_ready,
      acc_ready => hec_acc_ready,
      res       => hec_res
    );

  -- serial_in module
  s_in : process (clk_25m)
    variable xi, yi, zi : natural := 0;
  begin
    if rising_edge(clk_25m) then
      if reset then
        xi := 0; yi := 0; zi := 0;
        serial_in_rdy <= '0';
        hec_slice(zi)(yi)(xi) <= (others => '0'); 
      elsif (state = serial_in) and (serial_in_rdy = '0') then
        hec_slice(zi)(yi)(xi) <= serial_in_img; 
        xi := xi + 1;                              -- might cause timing issues (variable vs signal)
        if (xi = kx) then
          xi := 0;
          yi := yi + 1;
          if (yi = ky) then
            yi := 0;
            zi := zi + 1;
            if (zi = kz) then
              serial_in_rdy <= '1';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- serial_out module
  s_out : process (clk_25m)
    variable xi, yi, zi : natural := 0;
  begin
    if rising_edge(clk_25m) then
      if reset then
        xi := 0; yi := 0; zi := 0;
        serial_out_rdy <= '0';
        serial_out_conv <= (others => '0'); 
      elsif (state = serial_out) and (serial_out_rdy = '0') then
        serial_out_conv <= hec_res(zi)(yi)(xi);
        xi := xi + 1;                              -- might cause timing issues (variable vs signal)
        if (xi = ox) then
          xi := 0;
          yi := yi + 1;
          if (yi = oy) then
            yi := 0;
            zi := zi + 1;
            if (zi = oz) then
              serial_out_rdy <= '1';
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
  
  -- increment sxi syi szi
  -- inc_s : process (clk_100m) begin
  --   if rising_edge(clk_100m) then
  --     if (reset) then
  --       sxi <= 0; syi <= 0; szi <= 0; img_complete <= '0';
  --     elsif hec_acc_ready and not img_complete then
  --       sxi <= sxi + 1;
  --       if (sxi = sx) then syi <= syi + 1; sxi <= 0; end if;
  --       if (syi = oy) then szi <= szi + 1; syi <= 0; end if;
  --       if ((szi = oz-1) and (syi = oy-1) and (sxi = ox-1)) then img_complete <= '1'; end if;
  --     end if;
  --   end if;
  -- end process;

  process (all) begin
    if hec_acc_ready and not img_complete then
      sxi <= sxi + 1;
      if (sxi = sx) then syi <= syi + 1; sxi <= 0; end if;
      if (syi = oy) then szi <= szi + 1; syi <= 0; end if;
      if ((szi = oz-1) and (syi = oy-1) and (sxi = ox-1)) then img_complete <= '1'; end if;
    end if;
  end process;
  hec_sxi <= sxi when state = conv_slice;
  hec_syi <= syi when state = conv_slice;
  hec_szi <= szi when state = conv_slice;

  -- Control unit
  fsm : process (clk_25m) begin
    if rising_edge(clk_25m) then 
      if (reset) then
        state <= initial;
      else
        state <=
          serial_in  when ((state = initial   ) and (read_slice     = '1')) or ((hec_acc_ready  = '1') and (img_complete = '0')) else
          conv_slice when (state  = serial_in ) and (serial_in_rdy  = '1') else
          serial_out when (state  = conv_slice) and (img_complete   = '1') else
          final      when (state  = serial_out) and (serial_out_rdy = '1') else
        state;
      end if;
    end if;
  end process;
  hec_reset  <= '1' when state = serial_in  else '0';
  hec_start  <= '1' when state = conv_slice else '0';
  load_res   <= '1' when state = serial_out else '0';
  ready      <= '1' when state = final      else '0';

end architecture synth;


