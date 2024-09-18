library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity fft_tb is
end entity fft_tb;

architecture arch of fft_tb is

  constant nx, ny, nz : natural range 0 to 16 := 2;

  type test_tuple_t is array(0 to 1) of b25_3d_real_array(0 to nx-1)(0 to ny-1)(0 to nz-1);

  constant test_tuple : test_tuple_t := (
  ( ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ),
    ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ) ),
  ( ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ),
    ( ( "0000000010000000000000000",
        "0000000010000000000000000" ),
      ( "0000000010000000000000000",
        "0000000010000000000000000" ) ) )
  );

  signal   img_in,  ker_in  : b25_3d_real_array(0 to nx-1)(0 to ny-1)(0 to nz-1);
  signal   img_out, ker_out : b25_complex_array(0 to 16) := (others => (others => (others => '0')));
  signal   clock, start, reset, s_ready_i, s_ready_k, simulate : std_logic := '0';
  constant clockperiod : time := 1 ms; -- 1khz

begin

  clock <= (not clock) and simulate after clockperiod / 2;

  -- this is implied
  -- img_pad <= (0 to 1 => img_in(0 to 1), 3 to 4 => img_in(2 to 3), 9 to 10 => img_in(4 to 5), 12 to 13 => img_in(6 to 7), (others => (others => '0')));
  -- ker_pad <= (0 to 1 => ker_in(0 to 1), 3 to 4 => ker_in(2 to 3), 9 to 10 => ker_in(4 to 5), 12 to 13 => ker_in(6 to 7), (others => (others => '0')));

  dut0 : component fft
    generic map (2, 2, 2, 32)
    port map (
      i       => img_in,
      o       => img_out,
      clock   => clock,
      reset   => reset,
      start   => start,
      s_ready => s_ready_i
    );

  -- dut1 : component fft
  --   generic map (2, 2, 2, 32)
  --   port map (
  --     i       => ker_in,
  --     o       => ker_out,
  --     clock   => clock,
  --     start   => start,
  --     reset   => reset,
  --     s_ready => s_ready_k
  --   );

  test : process is
  begin

    simulate <= '1';
    img_in <= test_tuple(0);
    ker_in <= test_tuple(1);
    
    reset <= '1';
    wait for 2 ms;
    reset <= '0';
    start <= '1';
    wait until (s_ready_i = '1') for 50 ms ;
    start <= '0';

    simulate <= '0';
    stop;

  end process test;

end architecture arch;