library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity varshiftright is
  generic (
    len : natural := 8
  );
  port (
    data     : in    std_logic_vector(len - 1 downto 0);
    distance : in    std_logic_vector(integer(ceil(log2(real(len)))) - 1 downto 0);
    result   : out   std_logic_vector(len - 1 downto 0)
  );
end entity varshiftright;

architecture synth of varshiftright is

begin

  result <= data(len - 1) & std_logic_vector(shift_right(unsigned(data(len - 2 downto 0)), to_integer(unsigned(distance))));

end architecture synth;
