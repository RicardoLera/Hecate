
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity mul_cos_simm is
  port (
    a     : in    std_logic_vector(15 downto 0);
    const : in    std_logic_vector(15 downto 0);
    res   : out   std_logic_vector(31 downto 0)
  );
end entity mul_cos_simm;

architecture arch of mul_cos_simm is

-- SIGNAL parc : STD_LOGIC_VECTOR(49 DOWNTO 0);

begin

  -- simm_mul : PROCESS (a, const)
  --     VARIABLE prod : STD_LOGIC_VECTOR(24 DOWNTO 0);
  -- BEGIN

  -- END PROCESS; -- simm_mul

  res <= std_logic_vector(unsigned(a) * unsigned(const));
-- res <= parc(40 DOWNTO 16);

end architecture arch; -- arch
