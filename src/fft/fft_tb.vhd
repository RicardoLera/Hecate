  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity fft_tb is
  port (
    inp   : in b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
    ram   : out b25_complex_array(0 to n_points/2);
    clock : in std_logic := '0';
    ready : out std_logic := '0'
  );
end entity fft_tb;

architecture sim of fft_tb is

  signal   test_arr : b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1) := (others => (others => (others => (others => '0'))));
  signal   o : b25_complex_array(0 to n_points/2) := (others => (others => (others => '0')));
  signal   clk, start, reset, simulate, s_ready : std_logic := '0';
  constant clockperiod : time := 1 ms;

begin

  clk <= (not clk) and simulate after clockperiod / 2;

  dut : component fft
    port map (
      i       => test_arr,
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
    wait for 2 ms;
    for z in 0 to kz-1 loop
      for y in 0 to ky-1 loop
        for x in 0 to kx-1 loop
          test_arr(z)(y)(x) <= "0000000010000000000000000";
        end loop;
      end loop;
    end loop;

    reset <= '0';
    start <= '1';
    wait until (s_ready = '1') for 50 ms ;
    wait for 2 ms;

    test_arr(0)(0)(1) <= "0000000001000000000000000";
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



architecture synth of fft_tb is
  signal res   : b25_complex_array(0 to n_points/2) := (others => (others => (others => '0')));
  signal reset : std_logic := '1';
  signal start : std_logic := '0';
begin

  dut : component fft
    port map (
      i       => inp,
      o       => res,
      clock   => clock,
      reset   => reset,
      start   => start,
      s_ready => ready
    );

  test : process (clock) begin
    if rising_edge(clock) then
      if ready then
        start <= '0'; reset <= '1';
        ram <= res;
      elsif reset then
        start <= '1'; reset <= '0';
        ram <= (others => (others => (others => '0')));
      end if;
    end if;
  end process test;

end architecture synth;