library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_add is
  port (
    a   : in    std_logic_vector(24 downto 0);
    b   : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_add;

architecture arch of b25_add is

  signal sa, sb, add : signed(23 downto 0);

begin

  sa <= 
    -signed(a(23 downto 0))
      when (a(24)) else
    signed(a(23 downto 0));

  sb <=
    -signed(b(23 downto 0))
      when (b(24)) else
    signed(b(23 downto 0));
  
  add <= sa + sb;

  res(23 downto 0) <=
    std_logic_vector(-add)
      when add(add'left) else
    std_logic_vector(add);
      
  res(24) <= add(add'left);

end architecture arch;






  -- add : process (a, b) is

  --   variable sa, sb, st : signed(23 downto 0);

  -- begin

  --   sa := signed(a(23 downto 0));
  --   sb := signed(b(23 downto 0));

  --   if ((a(24) xor b(24)) = '1') then

  --     st := sa - sb;

  --     if (st < 0) then
  --       temp_res  <= std_logic_vector(-st);
  --       temp_sign <= b(24);
  --     else
  --       temp_res  <= std_logic_vector(st);
  --       temp_sign <= a(24);
  --     end if;
    
  --   else
  --     temp_res  <= std_logic_vector(sa + sb);
  --     temp_sign <= a(24);
  --   end if;

  -- end process add;

  -- res(23 downto 0) <= temp_res;
  -- res(24) <= temp_sign;













  -- Solution above uses slightly less hardware than working with unsigned  

  --   variable ua : unsigned(23 downto 0);
  --   variable ub : unsigned(23 downto 0);

  -- begin

  --   ua := unsigned(a(23 downto 0));
  --   ub := unsigned(b(23 downto 0));

  --   if ((a(24) xor b(24)) = '1') then
  --     if (ua > ub) then
  --       temp_res  <= std_logic_vector(ua - ub);
  --       temp_sign <= a(24);
  --     else
  --       temp_res  <= std_logic_vector(ub - ua);
  --       temp_sign <= b(24);
  --     end if;
  --   else
  --     temp_res  <= std_logic_vector(ua + ub);
  --     temp_sign <= a(24);
  --   end if;













