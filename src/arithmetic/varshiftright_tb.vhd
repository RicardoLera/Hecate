library ieee;
  use ieee.std_logic_1164.all;
  use ieee.math_real.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity varshiftright_tb is
end entity varshiftright_tb;

architecture rtl of varshiftright_tb is

  component varshiftright is
    generic (
      len : natural := 8
    );
    port (
      data     : in    std_logic_vector(len - 1 downto 0);
      distance : in    std_logic_vector(INTEGER(ceil(log2(real(len)))) - 1 downto 0);
      result   : out   std_logic_vector(len - 1 downto 0)
    );
  end component;

  signal i, o : std_logic_vector(7 downto 0);
  -- SIGNAL distance : NATURAL RANGE 0 TO 7 := 0;
  signal b_distance : std_logic_vector(2 downto 0);

  signal   clk             : std_logic := '0';
  signal   keep_simulating : std_logic := '0';  -- delimita o tempo de geração do clock
  constant clockperiod     : TIME      := 1 ms; -- frequencia 1KHz

begin

  clk <= (NOT clk) and keep_simulating AFTER clockperiod / 2;

  dut : component varshiftright
    generic map (
8
    )
    port map (
i,
 b_distance,
 o
    );

  test : process is
  begin

    keep_simulating <= '1';
    i               <= "10110101";

    for distance IN 0 to 7 loop

      b_distance <= std_logic_vector(to_unsigned(distance, 3));
      WAIT FOR 2 * clockperiod;

    end loop;

    keep_simulating <= '0';
    -- report integer'image(to_integer(unsigned(addr))) & " - " & integer'image(to_integer(unsigned(data)));
    -- REPORT INTEGER'image(to_integer(unsigned(res)));
    WAIT;

  end process test;

end architecture rtl;
