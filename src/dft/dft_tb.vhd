library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

  use std.env.stop;

entity dft_tb is
end entity dft_tb;

architecture arch of dft_tb is

  type test_tuple_t is array(1 downto 0) of b25_real_array(7 downto 0);

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

  signal   img_in,  ker_in  : b25_real_array(0 to 7);
  signal   img_out, ker_out : b25_complex_array(16 downto 0) := (others => (others => (others => '0')));
  signal   clock            : std_logic                 := '0';
  signal   start            : std_logic                 := '0';
  signal   reset            : std_logic                 := '0';
  signal   s_ready_i        : std_logic                 := '0';
  signal   s_ready_k        : std_logic                 := '0';
  constant clockperiod      : time                      := 1 ms; -- 1khz

begin

  clock <= (not clock) and start after clockperiod / 2;

  -- this is implied
  -- img_pad <= (0 to 1 => img_in(0 to 1), 3 to 4 => img_in(2 to 3), 9 to 10 => img_in(4 to 5), 12 to 13 => img_in(6 to 7), (others => (others => '0')));
  -- ker_pad <= (0 to 1 => ker_in(0 to 1), 3 to 4 => ker_in(2 to 3), 9 to 10 => ker_in(4 to 5), 12 to 13 => ker_in(6 to 7), (others => (others => '0')));

  dut0 : component dft
  port map (
    i       => img_in,
    o       => img_out,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => s_ready_i
  );

  dut1 : component dft
  port map (
    i       => ker_in,
    o       => ker_out,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => s_ready_k
  );

  test : process is
  begin

    img_in <= test_tuple(0);
    ker_in <= test_tuple(1);
    start  <= '1';
    wait for 200 ms;
    --wait until s_ready_i = '1' and s_ready_k = '1';
    start  <= '0';

    stop;
    

  end process test;

end architecture arch;