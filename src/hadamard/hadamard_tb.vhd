  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard_tb is
end entity hadamard_tb;

architecture sim of hadamard_tb is

  signal reset, start : std_logic;
  signal x_i          : std_logic_vector(24 downto 0);
  signal y_i          : std_logic_vector(24 downto 0);
  signal x_k          : std_logic_vector(24 downto 0);
  signal y_k          : std_logic_vector(24 downto 0);
  signal p_coefs_x    : b25_real_array(0 to n_points/4-1);
  signal p_coefs_y    : b25_real_array(0 to n_points/4-1);
  signal ready        : std_logic;

  signal   clk             : std_logic := '0';
  signal   keep_simulating : std_logic := '0';
  constant clockperiod     : time      := 1 ms;

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hadamard
    generic map (1)
    port map (
      clock     => clk,
      reset     => reset,
      start     => start,
      x_i       => x_i,
      y_i       => y_i,
      x_k       => x_k,
      y_k       => y_k,
      p_coefs_x => p_coefs_x,
      p_coefs_y => p_coefs_y,
      ready     => ready
    );

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
