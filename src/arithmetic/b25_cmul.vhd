library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity b25_cmul is -- put constant as generic later
  port (
    a   : in    std_logic_vector(24 downto 0);
    con : in    std_logic_vector(24 downto 0);
    res : out   std_logic_vector(24 downto 0)
  );
end entity b25_cmul;

architecture arch of b25_cmul is

  signal temp_res  : std_logic_vector(48 downto 0) := (OTHERS => '0');
  signal temp_sign : std_logic                     := '0';

begin

  temp_res  <= std_logic_vector(
                                resize(
                                        unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)),
                                        49
                                      )
                              );
  temp_sign <= a(24) xor con(24);

  res(23 downto 0) <= temp_res(39 downto 16);
  res(24)          <= '0' when temp_res = (temp_res'range => '0') else -- ensure zero has "positive" sign
                      temp_sign;

-- process(a, con)
--         constant f10 : std_logic_vector := X"FFFFFFFFFF";
--         variable temp_res : std_logic_vector(48 downto 0);
--         variable temp_sign : std_logic;
--     begin
--         temp_res := std_logic_vector(
--                         resize(
--                             unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)),
--                             49)
--                         );
--         temp_sign := a(24) XOR con(24);

--         if (temp_res = (temp_res'range => '0')) then
--             temp_sign := '0';
--         end if;

--         if (unsigned(temp_res) > unsigned(f10)) then -- 0x00ffffffffff
--             report "b25_cmul overflow" severity warning;
--         end if;

--         res(23 downto 0) <= temp_res(39 downto 16);
--         res(24) <= temp_sign;
--     end process;

end architecture arch;
