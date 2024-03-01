LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY b25_cmul IS
    PORT (
        a, con : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
        res : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
    );
END b25_cmul;

ARCHITECTURE arch OF b25_cmul IS

    SIGNAL temp_res : std_logic_vector(48 downto 0) := (OTHERS => '0');
    SIGNAL temp_sign : std_logic := '0';

BEGIN
    
    temp_res <= std_logic_vector(
        resize(
            unsigned(a(23 downto 0)) * unsigned(con(23 downto 0)),
            49)
        );
    temp_sign <= a(24) XOR con(24);

    res(23 downto 0) <= temp_res(39 downto 16);
    res(24) <= '0' when temp_res = (temp_res'range => '0') else -- ensure zero has "positive" sign
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


END arch;