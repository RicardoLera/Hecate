library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity b25_cmul is
  generic (
    con : std_logic_vector(24 downto 0)
  );
  port (
    a   : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_cmul;

architecture arch of b25_cmul is
  signal temp_res  : std_logic_vector(47 downto 0) := (others => '0');
begin

  temp_res  <= std_logic_vector(
      unsigned(a(23 downto 0)) * unsigned(con(23 downto 0))
  );

  res(24) <= a(24) xor con(24);
  res(23 downto 0) <= temp_res(39 downto 16);

end architecture arch;
