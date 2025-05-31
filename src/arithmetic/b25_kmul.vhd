library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_kmul is
  generic (
    con : std_logic_vector(24 downto 0)
  );
  port (
    a   : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_kmul;

architecture synth of b25_kmul is begin

  assert (resize(unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)), 40) srl 16 < to_unsigned(2**24, 40))
    report "b25_kmul OVERFLOW" severity warning;

  res(24) <= a(24) xor con(24);
  res(23 downto 0) <= std_logic_vector(
    resize(
      resize(
        unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)),
      40) srl 16,
    24)
  );

end architecture synth;
