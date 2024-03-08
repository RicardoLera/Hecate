library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity b25_add is
  port (
    a   : in    std_logic_vector(24 downto 0);
    b   : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_add;

architecture arch of b25_add is

  signal temp_res  : std_logic_vector(23 downto 0) := (OTHERS => '0');
  signal temp_sign : std_logic                     := '0';

begin

  process(a,b)
    variable ua : unsigned(23 downto 0);
    variable ub : unsigned(23 downto 0);
  begin
    ua := unsigned(a(23 downto 0));
    ub := unsigned(b(23 downto 0));
    if ((a(24) xor b(24)) = '1') then
      if (ua > ub) then
        temp_res <= std_logic_vector(ua - ub);
        temp_sign <= a(24);
      else
        temp_res <= std_logic_vector(ub - ua);
        temp_sign <= b(24);
      end if;
    else
      temp_res <= std_logic_vector(ua + ub);
      temp_sign <= a(24);
    end if;
  end process;

  -- temp_res <= std_logic_vector(unsigned(a(23 downto 0)) - unsigned(b(23 downto 0)))
  --             when ((a(24) xor b(24)) = '1') and (unsigned(a(23 downto 0)) > unsigned(b(23 downto 0))) else
  --             std_logic_vector(unsigned(b(23 downto 0)) - unsigned(a(23 downto 0)))
  --             when ((a(24) xor b(24)) = '1') and (unsigned(b(23 downto 0)) > unsigned(a(23 downto 0))) else
  --             std_logic_vector(unsigned(a(23 downto 0)) + unsigned(b(23 downto 0)));

  -- temp_sign <= a(24) when ((a(24) xor b(24)) = '1') and (unsigned(a(23 downto 0)) > unsigned(b(23 downto 0))) else
  --              b(24);

  res(23 downto 0) <= temp_res;
  res(24)          <= '0' when temp_res = (temp_res'range => '0') else -- ensure zero has "positive" sign
                      temp_sign;

end architecture arch;
