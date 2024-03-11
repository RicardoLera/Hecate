library ieee;
  use ieee.std_logic_1164.all;

package b25_types is

  type real_array is ARRAY (NATURAL RANGE <>) OF std_logic_vector(24 downto 0);

  type complex is ARRAY (0 to 1) OF std_logic_vector(24 downto 0);

  type complex_array is ARRAY (NATURAL RANGE <>) OF complex;

end package b25_types;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.b25_types.all;

entity fft_8 is
  port (
    i       : in    real_array(0 to 7);
    o       : out   complex_array(0 to 15);
    clock   : in    std_logic;
    start   : in    std_logic;
    reset   : in    std_logic;
    s_ready : out   std_logic
  );
end entity fft_8;

architecture arch of fft_8 is

  component b25_cmul is
    port (
      a   : in    std_logic_vector(24 downto 0);
      con : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  -- Cos reference
  --  0       1       2       3       4
  --  0       22,5    45      67,5    90
  --  I       W       X       Y       Z

  -- cos 22,5  -  1110110010000011    1
  -- cos 45    -  1011010100000100    2
  -- cos 67,5  -  0110000111110111    3

  type t_cos_val_ref is ARRAY(0 to 15) OF NATURAL RANGE 0 to 4;

  type t_cos_sig_ref is ARRAY(0 to 15) OF BOOLEAN;

  constant cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1);
  constant cos_sig_ref : t_cos_sig_ref := (FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE);

  type t_calc_vals is ARRAY(0 to 3) OF std_logic_vector(24 downto 0);

  type t_calc_vals_arr is ARRAY(0 to 7) OF t_calc_vals;

  signal calc_vals_arr                    : t_calc_vals_arr               := (OTHERS => (OTHERS => (OTHERS => '0')));
  signal add_a                            : complex_array(0 to 15)        := (OTHERS => (OTHERS => (OTHERS => '0')));
  signal add_b                            : complex_array(0 to 15)        := (OTHERS => (OTHERS => (OTHERS => '0')));
  signal add_r                            : complex_array(0 to 15)        := (OTHERS => (OTHERS => (OTHERS => '0')));
  signal fft_ready                        : std_logic_vector(15 downto 0) := (OTHERS => '0');

begin

  -- Multiplication Layer

  gen_calc_vals : for id IN 0 to 7 generate

    calc_vals_arr(id)(0) <= i(id);

    gen_mul_22_67 : if (id MOD 4 = 1) or (id MOD 4 = 3) generate

      mul_22 : component b25_cmul
        port map (
          a   => i(id),
          con => "0000000001110110010000100",
          res => calc_vals_arr(id)(1)
        );

      mul_45 : component b25_cmul
        port map (
          a   => i(id),
          con => "0000000001011010100000101",
          res => calc_vals_arr(id)(2)
        );

      mul_67 : component b25_cmul
        port map (
          a   => i(id),
          con => "0000000000110000111111000",
          res => calc_vals_arr(id)(3)
        );

    end generate gen_mul_22_67;

    gen_mul_45 : if (id MOD 4 = 2) generate

      mul_45 : component b25_cmul
        port map (
          a   => i(id),
          con => "0000000001011010100000100",
          res => calc_vals_arr(id)(2)
        );

    end generate gen_mul_45;

  end generate gen_calc_vals;

  -- Addition Layer

  gen_sums : for o_id in 0 to 15 generate

    sum_r : component b25_add
      port map (
        a   => add_a(o_id)(0),
        b   => add_b(o_id)(0),
        res => add_r(o_id)(0)
      );

    sum_i : component b25_add
      port map (
        a   => add_a(o_id)(1),
        b   => add_b(o_id)(1),
        res => add_r(o_id)(1)
      );

    sum_pro : process (clock) is

      variable i_id       : NATURAL RANGE 0 to 8;
      variable w, wi      : NATURAL RANGE 0 to 15;
      variable c, ci      : std_logic_vector(24 downto 0);

    begin

      if rising_edge(clock) then
        if (reset = '0' and start = '1') then
          if (i_id < 8) then

            w  := (i_id * o_id) MOD 16;
            wi := (4 - i_id * o_id) MOD 16;
            
            if (cos_val_ref(w) /= 4) then -- if the exponent of w is not 4
              c := calc_vals_arr(i_id)(cos_val_ref(w));
              add_a(o_id)(0) <= add_r(o_id)(0);
              add_b(o_id)(0)(23 downto 0) <= c(23 downto 0);
              add_b(o_id)(0)(24) <= not c(24) when cos_sig_ref(w) else
                                        c(24);
            end if;

            if (cos_val_ref(wi) /= 4) then -- if the exponent of w is not 0
              ci := calc_vals_arr(i_id)(cos_val_ref(wi));
              add_a(o_id)(1) <= add_r(o_id)(1);
              add_b(o_id)(1)(23 downto 0) <= ci(23 downto 0);
              add_b(o_id)(1)(24) <= not ci(24) when cos_sig_ref(wi) else
                                        ci(24);
            end if;

            i_id := i_id + 1;
          else 
            fft_ready(o_id) <= '1';
          end if;
        end if; 
      end if;
    end process sum_pro;

    o(o_id)(0)      <= (21 downto 0 => add_r(o_id)(0)(23 downto 2), -- "Divide" by sqrt(16)
                        23 downto 22 => "00",
                        24 => add_r(o_id)(0)(24)
                        );

    o(o_id)(1)      <= (21 downto 0 => add_r(o_id)(1)(23 downto 2),
                        23 downto 22 => "00",
                        24 => add_r(o_id)(1)(24)
                        );
                          
  end generate gen_sums;

  s_ready <= '1' when fft_ready = x"FFFF" else
             '0';

end architecture arch;