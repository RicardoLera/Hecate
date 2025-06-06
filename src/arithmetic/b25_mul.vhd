  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_mul is
  port (
    a   : in    s25;
    b   : in    s25;
    res : out   s25
  );
end entity b25_mul;

architecture synth of b25_mul is begin

  assert (resize(unsigned(a(23 downto 0)) * unsigned(b(23 downto 0)), 40) srl 16 < to_unsigned(2**24, 40))
    report "b25_kmul OVERFLOW" severity warning;

  res(24) <= a(24) xor b(24);
  res(23 downto 0) <= std_logic_vector(
    resize(
      resize(
        unsigned(a(23 downto 0)) * unsigned(b(23 downto 0)),
      40) srl 16,
    24)
  );

end architecture synth;
