library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity flux_inverter_tb is
end entity flux_inverter_tb;

architecture rtl of flux_inverter_tb is

  component flux_inverter is
    generic (
      size : natural := 8
    );
    port (
      clock    : in    std_logic;
      reset_s  : in    std_logic;
      reset_as : in    std_logic;
      load     : in    std_logic;
      inp      : in    std_logic_vector(size - 1 downto 0);
      nex      : in    std_logic_vector(size - 1 downto 0);
      outp     : out   std_logic_vector(size - 1 downto 0);
      new_bit  : out   std_logic;
      ready    : out   std_logic
    );
  end component;

  signal clk : std_logic := '1';
  signal rs  : std_logic;
  signal ras : std_logic;
  signal ld  : std_logic;
  signal re  : std_logic;
  signal nb  : std_logic;
  signal i   : std_logic_vector(7 downto 0);
  signal nx  : std_logic_vector(7 downto 0);
  signal o   : std_logic_vector(7 downto 0);

  signal   keep_simulating : std_logic := '0';  -- delimita o tempo de geração do clock
  constant clockperiod     : TIME      := 1 ms; -- frequencia 1KHz

begin

  clk <= (NOT clk) and keep_simulating AFTER clockperiod / 2;

  dut : component flux_inverter
    generic map (
8
    )
    port map (
clk,
 rs,
 ras,
 ld,
 i,
 nx,
 o,
 nb,
 re
    );

  test : process is
  begin

    keep_simulating <= '1';
    i               <= "10110101";
    nx              <= "10110101";
    rs              <= '0';
    ras             <= '0';
    ld              <= '0';
    WAIT FOR 10 * clockperiod;
    ld              <= '1';
    WAIT FOR 4 * clockperiod;
    i               <= "10110101";
    nx              <= "11010110";
    WAIT FOR clockperiod;
    i               <= "11010110";
    nx              <= "11010110";
    WAIT FOR 10 * clockperiod;
    keep_simulating <= '0';
    -- report integer'image(to_integer(unsigned(addr))) & " - " & integer'image(to_integer(unsigned(data)));
    -- REPORT INTEGER'image(to_integer(unsigned(res)));
    WAIT;

  end process test;

end architecture rtl;
