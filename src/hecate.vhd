library work;
  use work.polyanna_types.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity polyanna_mvp is
  port (
    img     : in    real_array(7 downto 0);
    ker     : in    real_array(7 downto 0);
    clock   : in    std_logic;
    reset   : in    std_logic;
    start   : in    std_logic;
    res     : out   complex_array(15 downto 0);
    o_ready : out   std_logic
  );
end entity polyanna_mvp;

architecture arch of polyanna_mvp is

  component hadamard is
    generic (
      lut_size : natural RANGE 1 to 4 := 1
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      start     : in    std_logic;
      x_i       : in    std_logic_vector(24 downto 0);
      y_i       : in    std_logic_vector(24 downto 0);
      x_k       : in    std_logic_vector(24 downto 0);
      y_k       : in    std_logic_vector(24 downto 0);
      lut       : in    std_logic_vector((lut_size * 25) - 1 downto 0);
      p_coefs_x : out   std_logic_vector((lut_size * 25) - 1 downto 0);
      p_coefs_y : out   std_logic_vector((lut_size * 25) - 1 downto 0);
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

  signal img_transf,   ker_transf : complex_array(0 to 15);

  type t_calc_vals_compl_aux is ARRAY (0 to 1) OF std_logic_vector(99 downto 0);

  type t_calc_vals_aux is ARRAY (0 to 15) OF t_calc_vals_compl_aux;

  signal calc_vals_aux : t_calc_vals_aux := (OTHERS => (OTHERS => (OTHERS => '0')));

  type t_calc_vals is ARRAY(0 to 3) OF std_logic_vector(24 downto 0);

  type t_calc_vals_comp is ARRAY(0 to 1) OF t_calc_vals;

  type t_calc_vals_comp_arr is ARRAY (0 to 15) OF t_calc_vals_comp;

  signal calc_vals,    calc_vals_neg : t_calc_vals_comp_arr := (OTHERS => (OTHERS => (OTHERS => (OTHERS => '0'))));

  signal ready_fft : std_logic_vector(0 to 1);
  signal ready_had : std_logic_vector(0 to 15);
  signal ffts_ready, hads_ready, s_ready : std_logic     := '0';





  type t_cos_val_ref is ARRAY(0 to 15) OF NATURAL RANGE 0 to 4;

  type t_cos_sig_ref is ARRAY(0 to 15) OF BOOLEAN;

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

  gen_calc_vals : for id in 0 to 15 generate

    gen_had_22_67 : if (id MOD 4 = 1) or (id MOD 4 = 3) generate

      had_22_67 : component hadamard
        generic map (
                4
        )
        port map (
          clock     => clock,
          reset     => reset,
          start     => start,
          x_i       => img_transf(id)(0),
          y_i       => img_transf(id)(1),
          x_k       => ker_transf(id)(0),
          y_k       => ker_transf(id)(1),
          lut       => "0000000000000000101011111" &
                "0000000000000001010001001" &
                "0000000000000001101001111" &
                "0000000000000001110010101",
          p_coefs_x => calc_vals_aux(id)(0),
          p_coefs_y => calc_vals_aux(id)(1),
          ready     => ready_had(id)
        );

      gen_negs_22_67 : for j in 0 to 3 generate
        calc_vals(id)(0)(j)     <= calc_vals_aux(id)(0)((25 * (j + 1)) - 1 downto (25 * j));
        calc_vals(id)(1)(j)     <= calc_vals_aux(id)(1)((25 * (j + 1)) - 1 downto (25 * j));
        calc_vals_neg(id)(0)(j) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(0)(j)));
        calc_vals_neg(id)(1)(j) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(1)(j)));
      end generate gen_negs_22_67;

    end generate gen_had_22_67;

    gen_had_45 : if (id MOD 4 = 2) generate

      had_22_67 : component hadamard
        generic map (
                2
        )
        port map (
          clock     => clock,
          reset     => reset,
          start     => start,
          x_i       => img_transf(id)(0),
          y_i       => img_transf(id)(1),
          x_k       => ker_transf(id)(0),
          y_k       => ker_transf(id)(1),
          lut       => "0000000000000001010001001" &
                "0000000000000001110010101",
          p_coefs_x => calc_vals_aux(id)(0)(49 DOWNTO 0),
          p_coefs_y => calc_vals_aux(id)(1)(49 DOWNTO 0),
          ready     => ready_had(id)
        );

      gen_negs_45 : for j in 0 to 1 generate
        calc_vals(id)(0)(j * 2)     <= calc_vals_aux(id)(0)((25 * (j + 1)) - 1 downto (25 * j));
        calc_vals(id)(1)(j * 2)     <= calc_vals_aux(id)(1)((25 * (j + 1)) - 1 downto (25 * j));
        calc_vals_neg(id)(0)(j * 2) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(0)(j * 2)));
        calc_vals_neg(id)(1)(j * 2) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(1)(j * 2)));
      end generate gen_negs_45;

    end generate gen_had_45;

    gen_had_alef : if (id MOD 4 = 0) generate

      had_22_67 : component hadamard
        generic map (
                1
        )
        port map (
          clock     => clock,
          reset     => reset,
          start     => start,
          x_i       => img_transf(id)(0),
          y_i       => img_transf(id)(1),
          x_k       => ker_transf(id)(0),
          y_k       => ker_transf(id)(1),
          lut       => "0000000000000001110010101",
          p_coefs_x => calc_vals(id)(0)(0),
          p_coefs_y => calc_vals(id)(1)(0),
          ready     => ready_had(id)
        );

      calc_vals_neg(id)(0)(0) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(0)(0)));
      calc_vals_neg(id)(1)(0) <= std_logic_vector(to_unsigned(1, 25) + unsigned(NOT calc_vals(id)(1)(0)));
    end generate gen_had_alef;

    summ_pro : process (calc_vals, calc_vals_neg) is

      variable re, im : unsigned(24 downto 0);

    begin

      re := (OTHERS => '0');
      im := (OTHERS => '0');

      for i_id in 0 to 15 loop

        if (cos_val_ref((i_id * id) MOD 16) /= 4) then
          if cos_sig_ref((i_id * id) MOD 16) then
            re := re + unsigned(calc_vals_neg(i_id)(0)(cos_val_ref((i_id * id) MOD 16)));
            im := im + unsigned(calc_vals_neg(i_id)(1)(cos_val_ref((i_id * id) MOD 16)));
          else
            re := re + unsigned(calc_vals(i_id)(0)(cos_val_ref((i_id * id) MOD 16)));
            im := im + unsigned(calc_vals(i_id)(1)(cos_val_ref((i_id * id) MOD 16)));
          end if;
        end if;

        if (cos_val_ref((4 - i_id * id) MOD 16) /= 4) then
          if cos_sig_ref((4 - i_id * id) MOD 16) then
            re := re + unsigned(calc_vals(i_id)(1)(cos_val_ref((4 - i_id * id) MOD 16)));
            im := im + unsigned(calc_vals_neg(i_id)(0)(cos_val_ref((4 - i_id * id) MOD 16)));
          else
            re := re + unsigned(calc_vals_neg(i_id)(1)(cos_val_ref((4 - i_id * id) MOD 16)));
            im := im + unsigned(calc_vals(i_id)(1)(cos_val_ref((4 - i_id * id) MOD 16)));
          end if;
        end if;

      end loop;

      res(id)(0) <= std_logic_vector(re);
      res(id)(1) <= std_logic_vector(im);

    end process summ_pro;

  end generate gen_calc_vals; -- gen_calc_vals

end architecture arch;
