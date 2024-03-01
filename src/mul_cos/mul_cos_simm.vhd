
LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
ENTITY mul_cos_simm IS
    PORT (
        a, const : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        res : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END mul_cos_simm;

ARCHITECTURE arch OF mul_cos_simm IS

    -- SIGNAL parc : STD_LOGIC_VECTOR(49 DOWNTO 0);

BEGIN
    -- simm_mul : PROCESS (a, const)
    --     VARIABLE prod : STD_LOGIC_VECTOR(24 DOWNTO 0);
    -- BEGIN

    -- END PROCESS; -- simm_mul

    res <= STD_LOGIC_VECTOR(unsigned(a) * unsigned(const));
    -- res <= parc(40 DOWNTO 16);
END arch; -- arch