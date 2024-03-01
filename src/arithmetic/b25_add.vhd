LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY b25_add IS
    PORT (
        a, b : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
        res : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
    );
END b25_add;

ARCHITECTURE arch OF b25_add IS

    SIGNAL temp_res : std_logic_vector(23 downto 0) := (OTHERS => '0');
    SIGNAL temp_sign : std_logic := '0';

BEGIN
    
    temp_res <= std_logic_vector(unsigned(a(23 downto 0)) - unsigned(b(23 downto 0)))
        when ((a(24) XOR b(24)) = '1') AND (unsigned(a(23 downto 0)) > unsigned(b(23 downto 0))) else
                std_logic_vector(unsigned(b(23 downto 0)) - unsigned(a(23 downto 0)))
        when ((a(24) XOR b(24)) = '1') AND (unsigned(b(23 downto 0)) > unsigned(a(23 downto 0))) else
                std_logic_vector(unsigned(a(23 downto 0)) + unsigned(b(23 downto 0)));

    temp_sign <= a(24) when ((a(24) XOR b(24)) = '1') AND (unsigned(a(23 downto 0)) > unsigned(b(23 downto 0))) else
                 b(24);

    res(23 downto 0) <= temp_res;
    res(24) <= '0' when temp_res = (temp_res'range => '0') else -- ensure zero has "positive" sign
        temp_sign;

END arch;