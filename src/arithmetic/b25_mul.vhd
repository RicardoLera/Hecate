library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity b25_mul is
  port (
    a   : in    std_logic_vector(24 downto 0);
    con : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_mul;

architecture arch of b25_mul is

  signal temp_res  : std_logic_vector(48 downto 0) := (others => '0');
  signal temp_sign : std_logic                     := '0';

begin

  temp_sign <= a(24) xor con(24);
  temp_res  <= std_logic_vector(
    resize(
      unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)),
      49
    )
  );

  res(24) <= '0' when temp_res = (temp_res'range => '0') else temp_sign; -- ensure zero has "positive" sign
  res(23 downto 0) <= temp_res(39 downto 16);

end architecture arch;
