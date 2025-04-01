-- Total non-redundant multiplications required: 33
-- Total additions required: 188 (some may be redundant)

-- Minimizing hardware we can do it in 3 mults and 13 adders, along 17 cycles
-- Details for this minimization are in the spreadsheet

-- For quick implementation, we can use a simplified method that uses 33 mults and 34 adders, along 32 cycles

  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity dft is
  port (
    i       : in    b25_real_array(0 to 7);
    o       : out   b25_complex_array(0 to 16);
    clock   : in    std_logic;
    start   : in    std_logic;
    reset   : in    std_logic;
    s_ready : out   std_logic
  );
end entity dft;


-- Simplified method (33 cmuls, 34 adders, 32 cycles)

architecture simp of dft is

  signal calc_vals_arr : t_calc_vals_arr               := (others => (others => (others => '0')));
  signal add_a         : b25_complex_array(0 to 16)    := (others => (others => (others => '0')));
  signal add_b         : b25_complex_array(0 to 16)    := (others => (others => (others => '0')));
  signal add_r         : b25_complex_array(0 to 16)    := (others => (others => (others => '0')));
  signal dft_ready     : std_logic_vector(16 downto 0) := (others => '0');

begin
  
  -- multiplication layer

  gen_mul_layer : for id in 0 to 7 generate
    
    constant id_pad : natural range 0 to 32 := pad3d(id);

  begin

    calc_vals_arr(id_pad)(0) <= i(id); -- v0 = 1 * N

    gen_v4 : if (id_pad /= 0) generate

      cmul_v4 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos4))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(4)
        );

    end generate gen_v4;

    gen_v2_v6 : if  (id_pad /= 0 and id_pad /= 4 and id_pad /= 12) generate

      cmul_v2 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos2))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(2)
        );
    
      cmul_v6 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos6))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(6)
        );

    end generate gen_v2_v6;

    gen_v1_v3_v5_v7 : if (id_pad /= 0 and id_pad /= 4 and id_pad /= 10 and id_pad /= 12) generate

      cmul_v1 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos1))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(1)
        );
    
      cmul_v3 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos3))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(3)
        );

      cmul_v5 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos5))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(5)
        );
      
      cmul_v7 : component b25_cmul
        generic map (
          con => ('0', "0000000", std_logic_vector(w_cos7))
        )
        port map (
          a   => i(id),
          res => calc_vals_arr(id_pad)(7)
        );
    
    end generate gen_v1_v3_v5_v7;

  end generate gen_mul_layer;



  -- addition layer

  gen_sums : for o_id in 0 to 16 generate

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

    sum_proc : process (clock) is          -- maybe make two processes, one for real one for imaginary, so they can be (more) concurrent

      variable i_id  : natural range 0 to 32 := 0;
      variable w, wi : natural range 0 to 32;
      variable c, ci : std_logic_vector(24 downto 0);

    begin

      if rising_edge(clock) then
        if (reset) then
          dft_ready(o_id) <= '0';
          i_id := 0;
          add_a(o_id) <= (others => (others => '0'));
          add_b(o_id) <= (others => (others => '0'));
        elsif (start) then
          if (i_id < 14) then                 -- end early due to 3d zero padding
            w  := (i_id * o_id) mod 32;
            wi := (8 - i_id * o_id) mod 32;

            if (cos_val_ref(w) /= 8) then                                          -- if the exponent of w is not 8
              c                           := calc_vals_arr(i_id)(cos_val_ref(w));
              add_a(o_id)(0)              <= add_r(o_id)(0);
              add_b(o_id)(0)(23 downto 0) <= c(23 downto 0);
              add_b(o_id)(0)(24)          <= not c(24) when cos_sig_ref(w)=1 else c(24);
            end if;

            if (cos_val_ref(wi) /= 8) then                                         -- if the exponent of w is not 0
              ci                          := calc_vals_arr(i_id)(cos_val_ref(wi));
              add_a(o_id)(1)              <= add_r(o_id)(1);
              add_b(o_id)(1)(23 downto 0) <= ci(23 downto 0);
              add_b(o_id)(1)(24)          <= not ci(24) when cos_sig_ref(wi)=1 else ci(24);
            end if;
            i_id := i_id + 1;
          else
            dft_ready(o_id) <= '1';
          end if;
        end if;
      end if;

    end process sum_proc;

    o(o_id)(0) <= add_r(o_id)(0);
    o(o_id)(1) <= add_r(o_id)(1);

  end generate gen_sums;

  s_ready <= and(dft_ready);

end architecture simp;



-- Optimized hardware method (3 cmuls, 13 adders, 17 cycles)

-- Adder order: 0 8 16   4 12   2 6 10 14    1 7 9 15   3 5 11 13

-- Multiplier order: 1-3-9-13-V4
--                   1-3-9-13-V2 1-3-9-13-V6 10-V4
--                   1-9-V1      1-9-V7      3-13-V3      3-13-V5 4-12-V4 10-V2 10-V6
--                   1-9-V3      1-9-V5      3-13-V7      3-13-V1

-- architecture m3d of dft is

-- begin

  

-- end architecture m3d;
