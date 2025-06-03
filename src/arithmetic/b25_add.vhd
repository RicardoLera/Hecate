-- Adding sign-magnitude to two's-complement

-- Example: [-3 + 2 = -1] = b3_111 + b3_010 = b3_101
-- b3_111 => 2c3_001 [b3(sign) = 1 -> 1'00' +1 = 2c3_101]
-- b3_010 => 2c3_010 [b3(sign) = 0 -> b3_010 = 2c3_010]
-- 2c3_101 + 2c3_010 = 2c3_111
-- 2c3_111 => b3_101 [2c3(sign) = 1 -> 1'00' +1 = b3_101]

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_add is
  port (
    a, b : in  std_logic_vector(24 downto 0); -- 25-bit_sign-magnitude [SMM]
    res  : out std_logic_vector(24 downto 0)  -- 25-bit_sign-magnitude [SMM] (overflow bit ignored)
  );
end entity b25_add;

architecture synth of b25_add is
  signal a_2c, b_2c, r_2c : signed(24 downto 0); -- [SCC]
begin
  assert (not (a(23) nand b(23))) report "b25_add OVERFLOW" severity warning;
  
  a_2c <= -signed('0' & a(23 downto 0)) when a(24) else signed('0' & a(23 downto 0));
  b_2c <= -signed('0' & b(23 downto 0)) when b(24) else signed('0' & b(23 downto 0));
  r_2c <= a_2c + b_2c;
  res  <= std_logic_vector(-signed('0' & r_2c(23 downto 0))) when r_2c(24) else std_logic_vector(signed('0' & r_2c(23 downto 0)));

end architecture synth;







-- Both of the following implementations infer 4 adders instead of 1 (3 used for sm -> 2c conversions)

-- architecture synth of b25_add is
--   signal a_2c, b_2c, r_2c : signed(24 downto 0); -- [SCC]
-- begin
--   assert (not (a(23) nand b(23))) report "b25_add OVERFLOW" severity warning;
  
--   a_2c <= -signed('0' & a(23 downto 0)) when a(24) else signed('0' & a(23 downto 0));
--   b_2c <= -signed('0' & b(23 downto 0)) when b(24) else signed('0' & b(23 downto 0));
--   r_2c <= a_2c + b_2c;
--   res  <= std_logic_vector(-signed('0' & r_2c(23 downto 0))) when r_2c(24) else std_logic_vector(signed('0' & r_2c(23 downto 0)));

-- end architecture synth;

-- architecture literal of b25_add is
--   signal a_2c, b_2c, r_2c : std_logic_vector(24 downto 0); -- [SCC]
-- begin
  
--   assert (not (a(23) nand b(23))) report "b25_add OVERFLOW" severity warning;
  
--   a_2c <= (std_logic_vector(unsigned('1' & not a(23 downto 0)) + 1)) when a(24) else a; 
--   b_2c <= (std_logic_vector(unsigned('1' & not b(23 downto 0)) + 1)) when b(24) else b; 
--   r_2c <= std_logic_vector(unsigned(a_2c) + unsigned(b_2c));      
--   res  <= (std_logic_vector(unsigned('1' & not r_2c(23 downto 0)) + 1)) when r_2c(24) else r_2c; 

-- end architecture literal;























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













