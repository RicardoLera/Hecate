library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity adder_carry is
  generic (
    size : natural := 32
  );
  port (
    a   : in    std_logic_vector(size - 1 downto 0);
    b   : in    std_logic_vector(size - 1 downto 0);
    cin : in    std_logic;
    o   : out   std_logic_vector(size - 1 downto 0)
  );
end entity adder_carry;

architecture synth_simm of adder_carry is

  signal cin_u : unsigned(0 downto 0);

begin

  cin_u <= to_unsigned(1, 1) when cin = '1' else
           to_unsigned(0, 1);
  o     <= std_logic_vector(unsigned(a) + unsigned(b) + cin_u);

end architecture synth_simm; -- synth
