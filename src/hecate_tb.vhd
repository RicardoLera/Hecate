library work;
  use work.b25_types.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.math_real.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity hecate_tb is
end entity hecate_tb;

architecture rtl of hecate_tb is

  component hecate is
    port (
      img     : in    real_array(0 to 7);
      ker     : in    real_array(0 to 7);
      clock   : in    std_logic;
      reset   : in    std_logic;
      start   : in    std_logic;
      res     : out   complex_array(0 to 15);
      o_ready : out   std_logic
    );
  end component;

  signal img, ker              : real_array(0 to 7);
  signal reset, start, o_ready : std_logic;
  signal res                   : complex_array(0 to 15);

  signal   clk             : std_logic := '0';
  signal   keep_simulating : std_logic := '0';
  constant clockperiod     : time      := 1 ms;

  type test_tuple_t is array(0 to 1) OF real_array(7 downto 0);
  constant test_tuple0 : test_tuple_t :=
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

  test : process is
  begin

    img <= test_tuple0(0);
    ker <= test_tuple0(1);

    keep_simulating <= '1';
    reset           <= '0';
    start           <= '1';

    wait until o_ready;
    start <= '0';

    wait for 25 * clockperiod;
    reset <= '1';
    wait for 5 * clockperiod;
    reset <= '0';

    wait for 20 * clockperiod;
    keep_simulating <= '0';

    wait;

  end process test;

end architecture rtl;
