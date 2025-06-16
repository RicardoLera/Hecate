  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity vivado_tb is
  port (
    rom_serial_i : in  t_signed  := (others => '0');
    rom_serial_k : in  t_signed  := (others => '0');
    ram_serial   : out t_signed  := (others => '0');
    clock, start : in  std_logic := '0';
    reset        : in  std_logic := '0';
    ready        : out std_logic := '0'
  );
end entity vivado_tb;

architecture synth of vivado_tb is

  component clk_wiz_0
    port (
      clk_in1  : in  std_logic;
      reset    : in  std_logic;
      locked   : out std_logic;
      clk_out1 : out std_logic;
      clk_out2 : out std_logic;
      clk_out3 : out std_logic
     );
  end component;

  signal locked, clk_125, clk_250, clk_500 : std_logic;

  signal img : t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal ker : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
  signal res : t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
  signal oa_ready, oa_start, serial_i_ready, serial_k_ready : std_logic := '0';

  signal load : std_logic := '1';
begin

  gen_clocks : clk_wiz_0
    port map (
      reset    => reset,
      locked   => locked,
      clk_in1  => clock,
      clk_out1 => clk_125,
      clk_out2 => clk_250,
      clk_out3 => clk_500
    );

  serial_in : process (clk_125) is
    variable izi, iyi, ixi, kzi, kyi, kxi : natural := 0;
  begin
    if rising_edge(clk_125) then
      if reset then
        izi := 0; iyi := 0; ixi := 0; kzi := 0; kyi := 0; kxi := 0;
        serial_i_ready <= '0'; serial_k_ready <= '0';
      elsif start and not serial_i_ready then
      
        if load then
        
          img(izi)(iyi)(ixi) <= rom_serial_i;
          ker(kzi)(kyi)(kxi) <= rom_serial_k;
          load <= not load;
         
        else

        if not serial_i_ready then
          ixi := ixi + 1;
          if (ixi = ix) then iyi := iyi + 1; ixi := 0; end if;
          if (iyi = iy) then izi := izi + 1; iyi := 0; end if;
          if (izi = iz) then serial_i_ready <= '1'; end if;
        end if;

        if not serial_k_ready then
          kxi := kxi + 1;
          if (kxi = kx) then kyi := kyi + 1; kxi := 0; end if;
          if (kyi = ky) then kzi := kzi + 1; kyi := 0; end if;
          if (kzi = kz) then serial_k_ready <= '1'; end if;
        end if;
        
        load <= not load;

        end if;
        
      end if;
    end if;
  end process serial_in;
  oa_start <= serial_i_ready and serial_k_ready;

  dut : component hecate
    port map (
      img   => img,
      ker   => ker,
      clock => clk_125,
      reset => reset,
      start => oa_start,
      res   => res,
      ready => oa_ready
    );

  serial_out : process (clk_125) is
    variable ozi, oyi, oxi : natural := 0;
  begin
    if rising_edge(clk_125) then
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