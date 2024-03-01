LIBRARY IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY mul_cos_simm_tb IS
END mul_cos_simm_tb;

ARCHITECTURE rtl OF mul_cos_simm_tb IS
    COMPONENT mul_cos_simm IS
        PORT (
            a, const : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            res : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL clock : STD_LOGIC := '0';
    SIGNAL keep_simulating : STD_LOGIC := '0'; -- delimita o tempo de geração do clock
    CONSTANT clockPeriod : TIME := 1 ms; -- frequencia 1KHz

    SIGNAL v1, v2 : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL res : STD_LOGIC_VECTOR(31 DOWNTO 0);

    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING IS
        VARIABLE b : STRING (1 TO a'length) := (OTHERS => NUL);
        VARIABLE stri : INTEGER := 1;
    BEGIN
        FOR i IN a'RANGE LOOP
            b(stri) := STD_LOGIC'image(a((i)))(2);
            stri := stri + 1;
        END LOOP;
        RETURN b;
    END FUNCTION;

BEGIN
    clock <= (NOT clock) AND keep_simulating AFTER clockPeriod/2;

    dut : mul_cos_simm PORT MAP(v1, v2, res);

    test : PROCESS
        VARIABLE prt : STRING(1 TO 1) := " ";

    BEGIN

        v1 <= "0011100101010011";
        v2 <= "1111111111111111";

        WAIT FOR clockPeriod;
        -- FOR id IN 0 TO 15 LOOP

        -- prt := " ";
        -- FOR i IN 0 TO res'length - 1 LOOP
        --     prt := prt & res(i)'image;
        -- END LOOP;
        REPORT to_string(res);

        -- REPORT INTEGER'image(to_integer(unsigned(res_dut(id)(0))));
        -- END LOOP;
        -- ASSERT false REPORT "Test: OK" SEVERITY failure;
        keep_simulating <= '0';
        WAIT;
    END PROCESS test;
END ARCHITECTURE rtl;