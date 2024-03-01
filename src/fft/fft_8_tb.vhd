LIBRARY work;
USE work.b25_types.ALL;
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fft_8_tb IS
END fft_8_tb;

ARCHITECTURE arch OF fft_8_tb IS

    COMPONENT fft_8 IS
        PORT (
            i : IN real_array(0 TO 7);
            o : OUT complex_array(0 TO 15)
            --        clock, start, reset : IN STD_LOGIC;
            --        busy : OUT STD_LOGIC
        );
    END COMPONENT;

    TYPE test_tuple_t IS ARRAY(1 DOWNTO 0) OF real_array(7 DOWNTO 0);
    CONSTANT test_tuple : test_tuple_t := (
    (
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000"
        ),
		  (
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000",
        "0000000010000000000000000"
        )
    );

    -- TYPE t_cos_val_ref IS ARRAY(0 TO 15) OF NATURAL RANGE 0 TO 4;
    -- TYPE t_cos_sig_ref IS ARRAY(0 TO 15) OF BOOLEAN;
    -- CONSTANT cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1);
    -- CONSTANT cos_sig_ref : t_cos_sig_ref := (FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE);

    -- TYPE t_calc_vals IS ARRAY(0 TO 3) OF STD_LOGIC_VECTOR(24 DOWNTO 0);
    -- TYPE t_calc_vals_arr IS ARRAY(0 TO 7) OF t_calc_vals;

    -- TYPE t_calc_vals_aux IS ARRAY(0 TO 2) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- TYPE t_calc_vals_aux_arr IS ARRAY(0 TO 7) OF t_calc_vals_aux;

    -- SIGNAL calc_vals_arr, calc_vals_arr_neg : t_calc_vals_arr;
    -- SIGNAL calc_vals_arr_aux : t_calc_vals_aux_arr;

    SIGNAL img_in, ker_in : real_array(7 DOWNTO 0);
    SIGNAL img_out, ker_out : complex_array(15 DOWNTO 0);
    SIGNAL keep_simulating : STD_LOGIC := '0'; -- generates clock
    CONSTANT clockPeriod : TIME := 1 ms; -- 1KHz

BEGIN

    dut0 : entity work.fft_8(arch) PORT MAP(img_in, img_out);
    dut1 : entity work.fft_8(arch) PORT MAP(ker_in, ker_out);

    test : PROCESS
    BEGIN
        img_in <= test_tuple(0);
        ker_in <= test_tuple(1);
        keep_simulating <= '1';
        WAIT FOR 100* clockPeriod;
        keep_simulating <= '0';
        wait;
    END PROCESS test;

END ARCHITECTURE;



