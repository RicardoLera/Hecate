library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hecate_tb_debug is
end entity hecate_tb_debug;

architecture sim of hecate_tb_debug is

  type test_tuple_t is array(0 to 1) of b25_real_array(7 downto 0);
  constant test_tuple : test_tuple_t :=
  (
    (
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000"
    ),
    (
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000",
      "0000000010000000000000000"
    )
  );

  signal img, ker          : b25_real_array(0 to 7);

  signal clk, reset, start : std_logic := '0';
  signal o_ready           : std_logic;
  signal res               : b25_real_array(0 to 26);

  signal keep_simulating   : std_logic := '0';
  constant clockperiod     : time      := 1 ms;

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hecate
    port map (
      img     => img,
      ker     => ker,
      clock   => clk,
      reset   => reset,
      start   => start,
      res     => res,
      o_ready => o_ready
    );

  test : process begin

    img <= test_tuple(0);
    ker <= test_tuple(1);

    keep_simulating <= '1';
    reset           <= '0';
    start           <= '1';

    wait until o_ready;
    start <= '0';

    wait for 5 * clockperiod;
    keep_simulating <= '0';

    wait;

  end process test;

end architecture sim;
