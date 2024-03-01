LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE b25_types IS
    TYPE real_array IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(24 DOWNTO 0);
    TYPE complex IS ARRAY (0 TO 1) OF STD_LOGIC_VECTOR(24 DOWNTO 0);
    TYPE complex_array IS ARRAY (NATURAL RANGE <>) OF complex;
END PACKAGE;

LIBRARY work;
USE work.b25_types.ALL;
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fft_8 IS
    PORT (
        i : IN real_array(0 TO 7);
        o : OUT complex_array(0 TO 15)
        --        clock, start, reset : IN STD_LOGIC;
        --        busy : OUT STD_LOGIC
    );
END fft_8;

ARCHITECTURE arch OF fft_8 IS

    COMPONENT b25_cmul IS
        PORT (
            a, con : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
            res : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT b25_add IS
        PORT (
            a, b : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
            res : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
        );
    END COMPONENT;

    -- Cos reference
    --  0       1       2       3       4
    --  0       22,5    45      67,5    90
    --  I       W       X       Y       Z   

    -- cos 22,5	-	1110110010000011		1
    -- cos 45	-	1011010100000100		2
    -- cos 67,5	-	0110000111110111		3

    TYPE t_cos_val_ref IS ARRAY(0 TO 15) OF NATURAL RANGE 0 TO 4;
    TYPE t_cos_sig_ref IS ARRAY(0 TO 15) OF BOOLEAN;
    CONSTANT cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1);
    CONSTANT cos_sig_ref : t_cos_sig_ref := (FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE);

    TYPE t_calc_vals IS ARRAY(0 TO 3) OF STD_LOGIC_VECTOR(24 DOWNTO 0);
    TYPE t_calc_vals_arr IS ARRAY(0 TO 7) OF t_calc_vals;
    SIGNAL calc_vals_arr, calc_vals_arr_neg : t_calc_vals_arr := (OTHERS => (OTHERS => (OTHERS =>'0')));
    --SIGNAL addR_a, addR_b, addR_r, addI_a, addI_b, addI_r : STD_LOGIC_VECTOR(24 DOWNTO 0) := (OTHERS => '0');
    SIGNAL add_a, add_b, add_r : complex_array(0 TO 15) := (OTHERS => (OTHERS => (OTHERS =>'0')));
	 
BEGIN

    gen_calc_vals : FOR id IN 0 TO 7 GENERATE

        calc_vals_arr(id)(0) <= i(id);
        gen_mul_22_67 : IF (id MOD 4 = 1) OR (id MOD 4 = 3) GENERATE
            mul_22 : b25_cmul PORT MAP(i(id), "0000000001110110010000011", calc_vals_arr(id)(0));
            mul_45 : b25_cmul PORT MAP(i(id), "0000000001011010100000100", calc_vals_arr(id)(1));
            mul_67 : b25_cmul PORT MAP(i(id), "0000000000110000111110111", calc_vals_arr(id)(2));
        END GENERATE gen_mul_22_67;

        gen_mul_45 : IF (id MOD 4 = 2) GENERATE
            mul_45 : b25_cmul PORT MAP(i(id), "0000000001011010100000100", calc_vals_arr(id)(1));
        END GENERATE gen_mul_45;

        gen_calc_vals_negs : FOR j IN 0 TO 3 GENERATE
            calc_vals_arr_neg(id)(j) <= STD_LOGIC_VECTOR(unsigned(NOT calc_vals_arr(id)(j)) + to_unsigned(1, 25));
        END GENERATE;

    END GENERATE;

    gen_sums : FOR o_id IN 0 TO 15 GENERATE
        summ_addR : b25_add PORT MAP (add_a(o_id)(0), add_b(o_id)(0), add_r(o_id)(0));
        summ_addI : b25_add PORT MAP (add_a(o_id)(1), add_b(o_id)(1), add_r(o_id)(1));
        
        summ_pro : PROCESS (calc_vals_arr, calc_vals_arr_neg)
            VARIABLE add_acc : complex_array(0 TO 7);
        BEGIN
            add_acc := (OTHERS => (OTHERS => (OTHERS =>'0')));
            FOR i_id IN 0 TO 7 LOOP

                IF cos_val_ref((i_id * o_id) MOD 16) /= 4 THEN

                     -- have to generate inside, FOR is not enough, that's software

                    IF (i_id /= 0) THEN
                        add_a(o_id)(0) <= add_acc(i_id-1)(0);
                    END IF;

                    IF cos_sig_ref((i_id * o_id) MOD 16) THEN
                        add_b(o_id)(0) <= calc_vals_arr_neg(i_id)(cos_val_ref((i_id * o_id) MOD 16));
                    ELSE
                        add_b(o_id)(0) <= calc_vals_arr(i_id)(cos_val_ref((i_id * o_id) MOD 16));
                    END IF;

                    IF (i_id /= 0) THEN
                        add_acc(i_id)(0) = add_acc(i_id-1)(0) + add_r(o_id)(0);
                    END IF;

                END IF;

                
                IF cos_val_ref((4 - i_id * o_id) MOD 16) /= 4 THEN

                    IF (i_id = 0) THEN
                        addI_a <= (OTHERS =>'0');
                    ELSE
                        addI_a <= addVec(i_id-1)(1);
                    END IF;

                    IF cos_sig_ref((4 - i_id * o_id) MOD 16) THEN
                        addI_b <= calc_vals_arr_neg(i_id)(cos_val_ref((4 - i_id * o_id) MOD 16));
                    ELSE
                        addI_b <= calc_vals_arr(i_id)(cos_val_ref((4 - i_id * o_id) MOD 16));
                    END IF;

                END IF;

            END LOOP;
            o(o_id)(0) <= addRes(7)(0);
            o(o_id)(1) <= addRes(7)(1);

        END PROCESS;
    END GENERATE;
END ARCHITECTURE;
