  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity fft_tb is
end entity fft_tb;

architecture sim of fft_tb is

  constant test_arr : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1) := (
    ( ( "0000000010000000000000000",
        "0000000001000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ),
    ( ( "0000000010000000000000000",
        "0000000001000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) )
  );

  constant test_arr2 : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1) := (
    ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ),
    ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) )
  );

  signal   i : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal   o : b25_complex_array(0 to 16) := (others => (others => (others => '0')));
  signal   clk, start, reset, simulate, s_ready : std_logic := '0';
  constant clockperiod : time := 1 ms;

begin

  clk <= (not clk) and simulate after clockperiod / 2;

  dut : component fft
    port map (
      i       => i,
      o       => o,
      clock   => clk,
      reset   => reset,
      start   => start,
      s_ready => s_ready
    );

  test : process is
  begin

    reset <= '1';
    simulate <= '1';
    i <= test_arr;
    wait for 2 ms;

    reset <= '0';
    start <= '1';
    wait until (s_ready = '1') for 50 ms ;
    wait for 2 ms;

    i <= test_arr2;
    reset <= '1';
    start <= '0';
    wait for 2 ms;

    reset <= '0';
    start <= '1';
    wait until (s_ready = '1') for 50 ms ;
    wait for 2 ms;

    start <= '0';
    wait for 1 ms;
    simulate <= '0';
    stop;

  end process test;

end architecture sim;