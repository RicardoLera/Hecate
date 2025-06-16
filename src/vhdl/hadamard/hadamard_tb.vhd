  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard_tb is
end entity hadamard_tb;

architecture sim of hadamard_tb is

  signal reset, start, ready : std_logic;
  signal img, ker, p         : t_signed_complex;

  signal   clk             : std_logic := '0';
  signal   keep_simulating : std_logic := '0';
  constant clockperiod     : time      := 1 ns;

  signal signed_one : t_signed := (others => '0');

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hadamard
    port map (
      clock => clk,
      reset => reset,
      start => start,
      img   => img,
      ker   => ker,
      p     => p,
      ready => ready
    );

  signed_one(signed_point) <= '1';
  img(0) <= signed_one;
  img(1) <= signed_one;
  ker(0) <= signed_one;
  ker(1) <= signed_one;

  -- values going into hadamard at n_idx=1
  --  x_i <= "0000000010110011100101100"; -- 0x1.672c
  --  y_i <= "1000001001010000000000111"; -- 0x4.a007
  --  x_k <= "0000000010110011100101100"; -- 0x1.672c
  --  y_k <= "1000001001010000000000111"; -- 0x4.a007

  test : process is
  begin

    keep_simulating <= '1';
    reset           <= '0';
    start           <= '1';

    wait until ready;
    start <= '0';

    wait for 25 * clockperiod;
    reset <= '1';
    wait for 5 * clockperiod;
    reset <= '0';

    wait for 20 * clockperiod;
    keep_simulating <= '0';

    wait;

  end process test;

end architecture sim;
