  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity fft_tb is
  port (
    inp     : in b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
    ram     : out b25_complex_array(0 to 16);
    clock   : in std_logic := '0';
    s_ready : out std_logic := '0'
  );
end entity fft_tb;

-- architecture sim of fft_tb is

--   constant nx, ny, nz : natural range 0 to 16 := 2;

--   constant test_arr : b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1) := (
--     ( ( "0000000010000000000000000",
--         "0000000001000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) ),
--     ( ( "0000000010000000000000000",
--         "0000000001000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) )
--   );

--   constant test_arr2 : b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1) := (
--     ( ( "0000000010000000000000000",
--         "0000000010000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) ),
--     ( ( "0000000010000000000000000",
--         "0000000010000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) )
--   );

--   signal   i : b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
--   signal   o : b25_complex_array(0 to 16) := (others => (others => (others => '0')));
--   signal   clk, start, reset, simulate : std_logic := '0';
--   constant clockperiod : time := 1 ms;

-- begin

--   clk <= (not clk) and simulate after clockperiod / 2;

--   dut : component fft
--     generic map (2, 2, 2, 32)
--     port map (
--       i       => i,
--       o       => o,
--       clock   => clk,
--       reset   => reset,
--       start   => start,
--       s_ready => s_ready
--     );

--   test : process is
--   begin

--     simulate <= '1';
--     i <= test_arr;

--     reset <= '0';
--     start <= '1';
--     wait until (s_ready = '1') for 50 ms ;

--     i <= test_arr2;
--     reset <= '1';
--     start <= '0';
--     wait for 2 ms;

--     reset <= '0';
--     start <= '1';
--     wait until (s_ready = '1') for 50 ms ;

--     start <= '0';
--     wait for 1 ms;
--     simulate <= '0';
--     stop;

--   end process test;

-- end architecture sim;




architecture synth of fft_tb is

  signal   res : b25_complex_array(0 to 16) := (others => (others => (others => '0')));
  signal   start, simulate : std_logic := '0';
  signal   reset : std_logic := '1';

begin

  dut : component fft
    generic map (2, 2, 2, 32)
    port map (
      i       => inp,
      o       => res,
      clock   => clock,
      reset   => reset,
      start   => start,
      s_ready => s_ready
    );

  test : process (clock) begin
    if rising_edge(clock) then
      if (s_ready) then
        ram <= res;
        start <= '0';
        reset <= '1';
        simulate <= '0';
      elsif (reset) then
        start <= '1';
        reset <= '0';
      end if;
    end if;
  end process test;

end architecture synth;