-- 3D Version -> N = 32
library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hecate is
  port (
    img     : in    b25_real_array(0 to 7);  -- 2x2x2 non-padded
    ker     : in    b25_real_array(0 to 7);
    clock   : in    std_logic;
    reset   : in    std_logic;
    start   : in    std_logic;
    res     : out   b25_real_array(0 to 26); -- 3x3x3
    o_ready : out   std_logic
  );
end entity hecate;

architecture arch of hecate is

  signal img_transf, ker_transf : b25_complex_array(0 to 16);

  type t_calc_matrix is array(0 to 16) of b25_real_array(0 to 7);
  signal calc_vals_x : t_calc_matrix := (others => (others => (others => '0')));
  signal calc_vals_y : t_calc_matrix := (others => (others => (others => '0')));

  signal ready_dft  : std_logic_vector(0 to 1);
  signal ready_had  : std_logic_vector(0 to 16);
  signal ready_idft : std_logic_vector(0 to 26) := (others => '0');
  signal dfts_ready, hads_ready, idfts_ready, s_ready : std_logic := '0';

  signal add_a, add_b, add_r : b25_real_array(0 to 26) := (others => (others => '0'));
  signal acc : b25_real_array(0 to 26) := (others => (others => '0'));
  
begin

  dft_in_img : component dft
  port map (
    i       => img,
    o       => img_transf,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => ready_dft(0)
  );

  dft_in_ker : component dft
  port map (
    i       => ker,
    o       => ker_transf,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => ready_dft(1)
  );

  -- gen_hads_read : process (ready_had) is
  --   variable rd : std_logic := '1';
  -- begin
  --   rd := '1';
  --   for id in 0 to 15 loop
  --     rd := rd and ready_had(id);
  --   end loop;
  --   hads_ready <= rd;
  -- end process gen_hads_read;

  dfts_ready  <= and(ready_dft);
  hads_ready  <= and(ready_had);
  idfts_ready <= and(ready_idft);

  sync_ready : process (clock) begin
    if rising_edge(clock) then
      if (reset = '1') then
        s_ready <= '0';
      elsif (idfts_ready = '1') then
        s_ready <= '1';
      end if;
    end if;
  end process sync_ready;

  o_ready <= s_ready;

  gen_calc_vals : for id in 0 to 16 generate

    had : component hadamard
      generic map (
        n_idx => id
      )
      port map (
        clock     => clock,
        reset     => reset,
        start     => dfts_ready,
        x_i       => img_transf(id)(0),
        y_i       => img_transf(id)(1),
        x_k       => ker_transf(id)(0),
        y_k       => ker_transf(id)(1),
        p_coefs_x => calc_vals_x(id),
        p_coefs_y => calc_vals_y(id),
        ready     => ready_had(id)
      );

  end generate gen_calc_vals;

  gen_sums : for o_id in 0 to 26 generate

    sum_r : component b25_add
      port map (
        a   => add_a(o_id),
        b   => add_b(o_id),
        res => add_r(o_id)
      );
    
    sum_out : component b25_add
      port map (
        a   => add_r(o_id),
        b   => acc(o_id),
        res => res(o_id)
      );

    sum_pro : process (clock) is

      variable i_id, w_ex, w_exc, w, wc: natural range 0 to 32;
      variable i_id_cor : natural range 0 to 16;
      variable a_sign, b_sign, wx_sign, wy_sign : std_logic;

    begin
      if rising_edge(clock) then
        if (reset = '0' and hads_ready = '1') then
          
          -- Each output sees all inputs
          if (i_id < 32) then  
            
            -- Hermitian symmetry
            if (i_id > 16) then
              i_id_cor := 32 - i_id;  
            else
              i_id_cor := i_id;
            end if;

            -- Exponent of w in full unit circle
            w_ex := (i_id * o_id) mod 32;
            -- report "o_id = " & to_string(o_id) & "   i = " & to_string(i_id) & "   w_ex = " & to_string(w_ex);
            
            -- Second and fourth quadrant reflections
            if (((w_ex > 8) and (w_ex <= 16)) or ((w_ex > 24) and (w_ex <= 31))) then
              w := (8 - (w_ex mod 8)) mod 8;
            else
              w := w_ex mod 8;
            end if;

            -- cos/sin pairs
            if w = 0 then
              wc := w;
            else
              wc := 8 - w;
            end if;

            -- (a + bi) * (wx + wyi) = [ws_x]a*wx + [ws_x]b*wx(i) + [ws_y]a*wy(i) + [-ws_y]b*wy
            -- add_a(0) = a_wx    add_b(0) = b_wy    add_a(1) = a_wy    add_b(1) = b_wx

            a_sign := calc_vals_x(i_id_cor)(0)(24);
            b_sign := calc_vals_y(i_id_cor)(0)(24);
            wx_sign := '1' when cos_sig_ref(w_ex)=1 else '0';
            wy_sign := '1' when sin_sig_ref(w_ex)=1 else '0';

            add_a(o_id) <= calc_vals_x(i_id_cor)(w);  -- a_wx
            add_b(o_id) <= calc_vals_y(i_id_cor)(wc); -- b_wy

            --if (i_id > 16) then b_sign := not b_sign; end if; -- Complex conjugate inversion (b)
            wy_sign := not wy_sign;                           -- DFT/IDFT inversion

            add_a(o_id)(24) <= a_sign xor wx_sign;
            add_b(o_id)(24) <= not (b_sign xor wy_sign);   -- i^2 inversion

            -- Orthogonal cancellations -> something is still leaking through, making this necessary
            if (w_ex=8 or w_ex=24) then -- cancel wx
              add_a(o_id) <= (others => '0');
            end if;
            if (w_ex=0 or w_ex=16) then -- cancel wy
              add_b(o_id) <= (others => '0');
            end if;
            
            acc(o_id) <= res(o_id);

            i_id := i_id + 1;

          else
            ready_idft(o_id) <= '1';   
          end if;

        end if;
      end if;
    end process sum_pro;

  end generate gen_sums;

end architecture arch;










-- if rising_edge(clock) then
--   if (reset = '0' and hads_ready = '1') then
--     if (i_id < 32) then

--       if (i_id > 16) then
--         i_id_cor := 32 - i_id;
--       else
--         i_id_cor := i_id;
--       end if;
--                                                   -- this is a complex multiplication by w. and now its input is also complex. you'll have to change this a lot more.
--       w   := (i_id_cor * o_id) mod 32;
--       wi  := (8 - i_id_cor * o_id) mod 32;

--       if (cos_val_ref(w) /= 8) then
--         c                           := calc_vals_x(i_id_cor)(cos_val_ref(w));
--         add_a(o_id)(0)              <= add_r(o_id)(0);
--         add_b(o_id)(0)(23 downto 0) <= c(23 downto 0);
--         add_b(o_id)(0)(24)          <= not c(24) when cos_sig_ref(w) else c(24);
--       end if;

--       if (cos_val_ref(wi) /= 8) then
--         ci                          := calc_vals_y(i_id_cor)(cos_val_ref(wi));
--         add_a(o_id)(1)              <= add_r(o_id)(1);
--         add_b(o_id)(1)(23 downto 0) <= ci(23 downto 0);
--         add_b(o_id)(1)(24)          <= not ci(24) when cos_sig_ref(wi) else ci(24);
--       end if;

--       i_id := i_id + 1;
--     else
--       -- dft_ready(o_id) <= '1';
--     end if;
--   end if;
-- end if;












-- summ_pro : process (calc_vals, calc_vals_neg) is

--   variable re, im : unsigned(24 downto 0);

-- begin

--   re := (others => '0');
--   im := (others => '0');

--   for i_id in 0 to 15 loop

--     if (cos_val_ref((i_id * id) mod 16) /= 4) then
--       if cos_sig_ref((i_id * id) mod 16) then
--         re := re + unsigned(calc_vals_neg(i_id)(0)(cos_val_ref((i_id * id) mod 16)));
--         im := im + unsigned(calc_vals_neg(i_id)(1)(cos_val_ref((i_id * id) mod 16)));
--       else
--         re := re + unsigned(calc_vals(i_id)(0)(cos_val_ref((i_id * id) mod 16)));
--         im := im + unsigned(calc_vals(i_id)(1)(cos_val_ref((i_id * id) mod 16)));
--       end if;
--     end if;

--     if (cos_val_ref((4 - i_id * id) mod 16) /= 4) then
--       if cos_sig_ref((4 - i_id * id) mod 16) then
--         re := re + unsigned(calc_vals(i_id)(1)(cos_val_ref((4 - i_id * id) mod 16)));
--         im := im + unsigned(calc_vals_neg(i_id)(0)(cos_val_ref((4 - i_id * id) mod 16)));
--       else
--         re := re + unsigned(calc_vals_neg(i_id)(1)(cos_val_ref((4 - i_id * id) mod 16)));
--         im := im + unsigned(calc_vals(i_id)(1)(cos_val_ref((4 - i_id * id) mod 16)));
--       end if;
--     end if;

--   end loop;

--   res(id)(0) <= std_logic_vector(re);
--   res(id)(1) <= std_logic_vector(im);

-- end process summ_pro;
















-- if (i_id < 15) then

--   if (i_id > 8) then      -- correct
--     i_id_cor := i_id - 8;
--   else
--     i_id_cor := i_id;
--   end if;
--                                               -- this is a complex multiplication by w. and now its input is also complex. you'll have to change this a lot more.
--   wx  := (i_id_cor * o_id) mod 16;
--   wy := (4 - i_id_cor * o_id) mod 16;

--   if (cos_val_ref(wx) /= 4) then                                          -- if the exponent of w is not 4
--     cx                           := calc_vals(i_id_cor)(0)(cos_val_ref(wx));
--     add_ax(o_id)(0)              <= add_rx(o_id)(0);
--     add_bx(o_id)(0)(23 downto 0) <= cx(23 downto 0);
--     add_bx(o_id)(0)(24)          <= not cx(24) when cos_sig_ref(wx) else
--                                     cx(24);
    
--     cxi                          := calc_vals(i_id_cor)(1)(cos_val_ref(wx));
--     add_ax(o_id)(1)              <= add_rx(o_id)(1);
--     add_bx(o_id)(1)(23 downto 0) <= cxi(23 downto 0);
--     add_bx(o_id)(1)(24)          <= not cxi(24) when cos_sig_ref(wx) else
--                                     cxi(24);
--   end if;

--   if (cos_val_ref(wx) /= 0) then                                          -- if the exponent of w is not 0
--     cy                           := calc_vals(i_id_cor)(0)(cos_val_ref(wy));
--     add_ay(o_id)(0)              <= add_ry(o_id)(0);
--     add_by(o_id)(0)(23 downto 0) <= cy(23 downto 0);
--     add_by(o_id)(0)(24)          <= not cy(24) when cos_sig_ref(wy) else
--                                     cy(24);
    
--     cyi                          := calc_vals(i_id_cor)(1)(cos_val_ref(wy));
--     add_ay(o_id)(1)              <= add_ry(o_id)(1);
--     add_by(o_id)(1)(23 downto 0) <= cyi(23 downto 0);
--     add_by(o_id)(1)(24)          <= not cyi(24) when cos_sig_ref(wy) else
--                                     cyi(24);   
--   end if;
--   i_id := i_id + 1;
-- else
--   -- dft_ready(o_id) <= '1';
-- end if;