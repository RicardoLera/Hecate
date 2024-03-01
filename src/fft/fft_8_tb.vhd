library work;
  use work.b25_types.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity fft_8_tb is
end entity fft_8_tb;

architecture arch of fft_8_tb is

  component fft_8 is
    port (
      i       : in    real_array(0 to 7);
      o       : out   complex_array(0 to 15);
      clock   : in    std_logic;
      start   : in    std_logic;
      reset   : in    std_logic;
      s_ready : out   std_logic
    );
  end component;

  type test_tuple_t is ARRAY(1 downto 0) OF real_array(7 downto 0);

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

  signal   img_in,  ker_in  : real_array(7 downto 0);
  signal   img_out, ker_out : complex_array(15 downto 0) := (OTHERS => (OTHERS => (OTHERS => '0')));
  signal   clock            : std_logic                  := '0';
  signal   start            : std_logic                  := '0';
  signal   reset            : std_logic                  := '0';
  signal   s_ready_i        : std_logic                  := '0';
  signal   s_ready_k        : std_logic                  := '0';
  constant clockperiod      : TIME                       := 1 ms; -- 1KHz

begin

  clock <= (NOT clock) and start AFTER clockperiod / 2;

  dut0 : component fft_8
    port map (
      i       => img_in,
      o       => img_out,
      clock   => clock,
      start   => start,
      reset   => reset,
      s_ready => s_ready_i
    );

  dut1 : component fft_8
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
    wait until s_ready_i = '1' and s_ready_k = '1';
    start  <= '0';
    wait;

  end process test;

end architecture arch;



