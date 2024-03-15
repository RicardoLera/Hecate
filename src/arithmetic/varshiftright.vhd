library ieee;
  use ieee.std_logic_1164.all;
  use ieee.math_real.all;
  use ieee.numeric_std.all;

entity varshiftright is
  generic (
    len : natural := 8
  );
  port (
    data     : in    std_logic_vector(len - 1 downto 0);
    distance : in    std_logic_vector(INTEGER(ceil(log2(real(len)))) - 1 downto 0);
    result   : out   std_logic_vector(len - 1 downto 0)
  );
end entity varshiftright;

architecture syn of varshiftright is

begin

  result <= std_logic_vector(shift_right(unsigned(data), to_integer(unsigned(distance))));

end architecture syn;
