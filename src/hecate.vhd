library work;
  use work.b25_types.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hecate is
  port (
    img     : in    real_array(0 to 7);
    ker     : in    real_array(0 to 7);
    clock   : in    std_logic;
    reset   : in    std_logic;
    start   : in    std_logic;
    res     : out   complex_array(0 to 15);
    o_ready : out   std_logic
  );
end entity hecate;

architecture arch of hecate is

  component hadamard is
    generic (
      logn  : natural range 1 to 3 := 3;
      n_idx : natural range 0 to 8 := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      start     : in    std_logic;
      x_i       : in    std_logic_vector(24 downto 0);
      y_i       : in    std_logic_vector(24 downto 0);
      x_k       : in    std_logic_vector(24 downto 0);
      y_k       : in    std_logic_vector(24 downto 0);
      p_coefs_x : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
      p_coefs_y : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
      ready     : buffer std_logic
    );
  end component;

  component fft_8 is
    port (
      i       : in    real_array(0 to 7);
      o       : out   complex_array(0 to 8);
      clock   : in    std_logic;
      start   : in    std_logic;
      reset   : in    std_logic;
      s_ready : out   std_logic
    );
  end component;

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  signal img_transf, ker_transf : complex_array(0 to 8);

  type t_calc_vals_c_aux is array (0 to 1) OF std_logic_vector(99 downto 0);
  type t_calc_vals_aux is array (0 to 8) OF t_calc_vals_c_aux;
  signal calc_vals_aux : t_calc_vals_aux := (others => (others => (others => '0')));

  type t_calc_vals is array(0 to 3) OF std_logic_vector(24 downto 0);
  type t_calc_vals_c is array(0 to 1) OF t_calc_vals;
  type t_calc_vals_c_arr is array (0 to 8) OF t_calc_vals_c;
  signal calc_vals : t_calc_vals_c_arr := (others => (others => (others => (others => '0'))));

  signal ready_fft : std_logic_vector(0 to 1);
  signal ready_had : std_logic_vector(0 to 8);
  signal ffts_ready, hads_ready, s_ready : std_logic := '0';

  signal add_a, add_b, add_r : complex_array(0 to 15) := (others => (others => (others => '0')));

  type t_cos_val_ref is array(0 to 15) OF natural range 0 to 4;
  type t_cos_sig_ref is array(0 to 15) OF boolean;
  constant cos_val_ref         : t_cos_val_ref := (0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1);
  constant cos_sig_ref         : t_cos_sig_ref := (FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE);
  
begin

  fft_in_img : component fft_8
  port map (
    i       => img,
    o       => img_transf,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => ready_fft(0)
  );

  fft_in_ker : component fft_8
  port map (
    i       => ker,
    o       => ker_transf,
    clock   => clock,
    start   => start,
    reset   => reset,
    s_ready => ready_fft(1)
  );

  ffts_ready <= and(ready_fft);

  -- gen_hads_read : process (ready_had) is
  --   variable rd : std_logic := '1';
  -- begin
  --   rd := '1';
  --   for id in 0 to 15 loop
  --     rd := rd and ready_had(id);
  --   end loop;
  --   hads_ready <= rd;
  -- end process gen_hads_read;

  hads_ready <= and(ready_had);

  sync_ready : process (clock) is
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        s_ready <= '0';
      else
        if (hads_ready = '1') then
          s_ready <= '1';
        end if;
      end if;
    end if;
  end process sync_ready;

  o_ready <= s_ready;

  gen_calc_vals : for id in 0 to 8 generate

    had : component hadamard
      generic map (
        logn  => 3,
        n_idx => id
      )
      port map (
        clock     => clock,
        reset     => reset,
        start     => ffts_ready,
        x_i       => img_transf(id)(0),
        y_i       => img_transf(id)(1),
        x_k       => ker_transf(id)(0),
        y_k       => ker_transf(id)(1),
        p_coefs_x => calc_vals_aux(id)(0),
        p_coefs_y => calc_vals_aux(id)(1),
        ready     => ready_had(id)
      );

    unroll_calc_vals : for j in 0 to 3 generate
      calc_vals(id)(0)(j) <= calc_vals_aux(id)(0)((25 * (j + 1)) - 1 downto (25 * j));
      calc_vals(id)(1)(j) <= calc_vals_aux(id)(1)((25 * (j + 1)) - 1 downto (25 * j));
    end generate unroll_calc_vals;

  end generate gen_calc_vals;

  gen_sums : for o_id in 0 to 15 generate       -- correct for hermitian symmetry

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

      variable i_id, w, wi: natural range 0 to 15;
      variable i_id_cor : natural range 0 to 8;  
      variable c, ci : std_logic_vector(24 downto 0);

    begin

      if rising_edge(clock) then
        if (reset = '0' and hads_ready = '1') then
          if (i_id < 15) then

            if (i_id > 8) then      -- correct
              i_id_cor := i_id - 8;
            else
              i_id_cor := i_id;
            end if;
                                                        -- this is a complex multiplication by w. And now its input is also complex. you'll have to change this a lot more.
            w   := (i_id_cor * o_id) mod 16;
            wi  := (4 - i_id_cor * o_id) mod 16;

            if (cos_val_ref(w) /= 4) then
              c                           := calc_vals(i_id_cor)(0)(cos_val_ref(w));
              add_a(o_id)(0)              <= add_r(o_id)(0);
              add_b(o_id)(0)(23 downto 0) <= c(23 downto 0);
              add_b(o_id)(0)(24)          <= not c(24) when cos_sig_ref(w) else c(24);
            end if;

            if (cos_val_ref(wi) /= 4) then
              ci                          := calc_vals(i_id_cor)(1)(cos_val_ref(wi));
              add_a(o_id)(1)              <= add_r(o_id)(1);
              add_b(o_id)(1)(23 downto 0) <= ci(23 downto 0);
              add_b(o_id)(1)(24)          <= not ci(24) when cos_sig_ref(wi) else ci(24);
            end if;

            i_id := i_id + 1;
          else
            -- fft_ready(o_id) <= '1';
          end if;
        end if;
      end if;

    end process sum_pro;

    res(o_id)(0) <= add_r(o_id)(0)(24) & "00" & add_r(o_id)(0)(23 downto 2); -- "Divide" by sqrt(16)
    res(o_id)(1) <= add_r(o_id)(1)(24) & "00" & add_r(o_id)(1)(23 downto 2);

  end generate gen_sums;

end architecture arch;








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
--                                               -- this is a complex multiplication by w. And now its input is also complex. you'll have to change this a lot more.
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
--   -- fft_ready(o_id) <= '1';
-- end if;