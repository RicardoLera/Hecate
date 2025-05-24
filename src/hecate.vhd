  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate is
  port (
    img_transf          : in b25_complex_array(0 to n_points/2);
    ker_transf          : in b25_complex_array(0 to n_points/2);
    clock, reset, start : in std_logic;
    res                 : out b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
    ready               : out std_logic
  );
end entity hecate;

architecture synth of hecate is

  signal ready_had  : std_logic_vector(0 to n_points/2);
  signal ready_idft : std_logic_vector(0 to n_points_nopad-1) := (others => '0');
  signal hads_ready, idfts_ready, s_ready : std_logic := '0';

  type t_calc_matrix is array(0 to n_points/2) of b25_real_array(0 to n_points/4-1);
  signal calc_vals_x : t_calc_matrix := (others => (others => (others => '0')));
  signal calc_vals_y : t_calc_matrix := (others => (others => (others => '0')));

  signal res_buff : b25_real_array(0 to n_points_nopad-1);

begin

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
  ready <= s_ready;

  gen_calc_vals : for id in 0 to n_points/2 generate
    had : component hadamard
      generic map (n_idx => id)
      port map (
        clock     => clock,
        reset     => reset,
        start     => start,
        x_i       => img_transf(id)(0),
        y_i       => img_transf(id)(1),
        x_k       => ker_transf(id)(0),
        y_k       => ker_transf(id)(1),
        p_coefs_x => calc_vals_x(id),
        p_coefs_y => calc_vals_y(id),
        ready     => ready_had(id)
      );
  end generate gen_calc_vals;

  gen_sums : for o_id in 0 to n_points_nopad-1 generate
    signal add_a, add_b, add_r : b25_real_array(0 to n_points_nopad-1) := (others => (others => '0'));
    signal acc : b25_real_array(0 to n_points_nopad-1) := (others => (others => '0'));
  begin

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
        res => res_buff(o_id)
      );

    sum_pro : process (clock) is
      variable i_id, w_ex, w, wc: natural;
      variable i_id_cor : natural;
      variable a_sign, b_sign, wx_sign, wy_sign : std_logic;
    begin
      if rising_edge(clock) then
        if (reset) then
          ready_idft(o_id) <= '0';
          i_id := 0;
          add_a(o_id) <= (others => '0');
          add_b(o_id) <= (others => '0');
          acc(o_id)   <= (others => '0');
        elsif (hads_ready = '1') then
          
          -- Each output sees all inputs
          if (i_id < n_points) then  
            
            -- Hermitian symmetry
            if (i_id > n_points/2) then
              i_id_cor := n_points - i_id;  
            else
              i_id_cor := i_id;
            end if;

            -- Exponent of w in full unit circle
            w_ex := (i_id * o_id) mod n_points;
            -- report "o_id = " & to_string(o_id) & "   i = " & to_string(i_id) & "   w_ex = " & to_string(w_ex);
            
            -- Second and fourth quadrant reflections
            if (((w_ex > n_points/4) and (w_ex <= n_points/2)) or ((w_ex > 3*n_points/4) and (w_ex <= n_points-1))) then
              w := (n_points/4 - (w_ex mod (n_points/4))) mod (n_points/4);
            else
              w := w_ex mod (n_points/4);
            end if;

            -- cos/sin pairs
            if w = 0 then
              wc := w;
            else
              wc := n_points/4 - w;
            end if;

            -- (a + bi) * (wx + wyi) = [ws_x]a*wx + [ws_x]b*wx(i) + [ws_y]a*wy(i) + [-ws_y]b*wy
            -- add_a(0) = a_wx    add_b(0) = b_wy    add_a(1) = a_wy    add_b(1) = b_wx

            a_sign  := calc_vals_x(i_id_cor)(0)(24);
            b_sign  := calc_vals_y(i_id_cor)(0)(24);
            wx_sign := '1' when ((w_ex > n_points/4) and (w_ex < 3*n_points/4)) else '0';
            wy_sign := '1' when (w_ex >= n_points/2) else '0';

            if (i_id > n_points/2) then b_sign := not b_sign; end if; -- Complex conjugate inversion (b)
            wy_sign := not wy_sign;  -- DFT/IDFT inversion

            add_a(o_id)(23 downto 0) <= calc_vals_x(i_id_cor)(w)(23 downto 0);  -- a_wx
            add_b(o_id)(23 downto 0) <= calc_vals_y(i_id_cor)(wc)(23 downto 0); -- b_wy

            add_a(o_id)(24) <= a_sign xor wx_sign;
            add_b(o_id)(24) <= not (b_sign xor wy_sign);  -- i^2 inversion

            -- Orthogonal cancellations -> I'm not sure why, but this is still necessary
            if ((w_ex=n_points/4) or (w_ex=3*n_points/4)) then -- cancel wx
              add_a(o_id) <= (others => '0');
            end if;
            if ((w_ex=0) or (w_ex=n_points/2)) then -- cancel wy
              add_b(o_id) <= (others => '0');
            end if;
            
            acc(o_id) <= res_buff(o_id);

            i_id := i_id + 1;

          else
            ready_idft(o_id) <= '1';   
          end if;

        end if;
      end if;
    end process sum_pro;
  end generate gen_sums;

  --Output Layer (unrasterize)
  gen_z : for z in 0 to nz-1 generate
    gen_y : for y in 0 to ny-1 generate
      gen_x : for x in 0 to nx-1 generate
        constant idx : natural := x + y*nx + z*nx*ny;
      begin
        gen_if : if (idx <= n_points_nopad-1) generate
          res(z)(y)(x) <= res_buff(idx) when idfts_ready = '1' else (others => '0');
        end generate gen_if;
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

end architecture synth;