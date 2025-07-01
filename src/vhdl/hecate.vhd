  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
entity hecate is
  port (
    slice, ker          : in  t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
    clock, reset, start : in  std_logic;
    sxi, syi, szi       : in  natural;
    ker_ready           : out std_logic;
    acc_ready           : out std_logic;
    res                 : out t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1)
  );
end entity hecate;

-- This arch is optimized in terms of area. It uses 1 hadamard_arr and 1 fft
architecture area_opt of hecate is

  -- Wires
  signal ker_raster, slice_raster : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

  signal fft_in               : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0')));
  signal fft_out              : t_signed_complex_array(0 to n_points-1);
  signal fft_start, fft_ready : std_logic := '0';
  signal fft_reset            : std_logic := '1';
  signal fft_clockwise        : std_logic := '0';

  signal had_img, had_ker     : t_signed_complex_array(0 to n_points/2) := (others => (others => (others => '0')));
  signal had_out              : t_signed_complex_array(0 to n_points/2);
  signal had_start, had_ready : std_logic := '0';
  signal had_reset            : std_logic := '1';

  signal prod_sym             : t_signed_complex_array(0 to n_points-1);
  signal conv, add            : t_signed_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);

  -- Registers
  signal state      : t_hec_state := initial;
  signal acc        : t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
  signal ker_transf : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0')));
  signal prod       : t_signed_complex_array(0 to n_points/2) := (others => (others => (others => '0')));

begin

  fft_single : component fft
    port map (
      i         => fft_in,
      o         => fft_out,
      clock     => clock,
      reset     => fft_reset,
      start     => fft_start,
      clockwise => fft_clockwise,
      s_ready   => fft_ready
    );
  
  had_arr_single : component hadamard_arr
    port map (
      img_transf => had_img,
      ker_transf => had_ker,
      clock      => clock,
      reset      => had_reset,
      start      => had_start,
      res        => had_out,
      ready      => had_ready
    );

  -- Accumulation adders
  gen_oa_adds_z : for z in 0 to nz-1 generate
    gen_oa_adds_y : for y in 0 to ny-1 generate
      gen_oa_adds_x : for x in 0 to nx-1 generate
        constant n : natural := x + y*nx + z*nx*ny;
      begin
        conv(z)(y)(x) <= fft_out(n)(0);
        add(z)(y)(x)  <= conv(z)(y)(x) + acc(szi*kz+z)(syi*ky+y)(sxi*kx+x);
      end generate gen_oa_adds_x;
    end generate gen_oa_adds_y;
  end generate gen_oa_adds_z;

  -- Signal rasterization / derasterization
  gen_z : for z in 0 to kz-1 generate
    gen_y : for y in 0 to ky-1 generate
      gen_x : for x in 0 to kx-1 generate
        constant n : natural := x + y*nx + z*nx*ny;
      begin
        slice_raster(n) <= (slice(z)(y)(x), signed_zero);
        ker_raster(n)   <= (ker(z)(y)(x), signed_zero);
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

  -- Hermitian symmetry
  process (all) begin
    for n in 0 to n_points-1 loop
      if n <= n_points/2 then 
        prod_sym(n) <= prod(n);
      else
        prod_sym(n) <= (prod(n_points-n)(0), -prod(n_points-n)(1));
      end if;
    end loop;
  end process;

  -- Control unit
  fsm : process (clock) begin
    if rising_edge(clock) then 
      if (reset) then
        state <= initial;
      else
        state <=
          ker_fft    when (state = initial   ) and (start       = '1') else
          latch_ker  when (state = ker_fft   ) and (fft_ready   = '1') else
          slice_fft  when (state = latch_ker ) or  (state = sl_reset)  else
          had        when (state = slice_fft ) and (fft_ready   = '1') else
          latch_had  when (state = had       ) and (had_ready   = '1') else
          ifft       when (state = latch_had )                         else
          accumulate when (state = ifft      ) and (fft_ready   = '1') else
          hold       when (state = accumulate)                         else
          sl_reset   when (state = hold)       and (start       = '1') else
        state;
      end if;
    end if;
  end process;
  ker_ready <= '1' when state = latch_ker else '0' when state = initial;
  acc_ready <= '1' when state = hold else '0';

  -- Reg assignments
  regs : process (clock) begin
    if rising_edge(clock) then

      ker_transf <= fft_out when state = latch_ker else (others => (others => (others => '0'))) when state = initial;
      prod       <= had_out when state = latch_had else (others => (others => (others => '0'))) when state = initial;

      for z in 0 to nz-1 loop
        for y in 0 to ny-1 loop
          for x in 0 to nx-1 loop
            if state = initial then
              acc <= (others => (others => (others => (others => '0'))));
            elsif state = accumulate then
              acc(szi*kz+z)(syi*ky+y)(sxi*kx+x) <= add(z)(y)(x);
            end if;
          end loop;
        end loop;
      end loop;

    end if;
  end process;

  -- Signal assignments
  assigns : process (all) begin
    case state is

      when ker_fft =>
        fft_reset     <= '0';
        fft_start     <= '1';
        fft_clockwise <= '0';
        fft_in        <= ker_raster;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));
      
      when latch_ker =>
        fft_reset     <= '1'; -- fft holds output on reset, no need to give it a reset state
        fft_start     <= '0';
        fft_clockwise <= '0';
        fft_in        <= ker_raster;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when slice_fft =>
        fft_reset     <= '0';
        fft_start     <= '1';
        fft_clockwise <= '0';
        fft_in        <= slice_raster;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when had =>
        fft_reset     <= '0';
        fft_start     <= '0';
        fft_clockwise <= '0';
        fft_in        <= slice_raster;
        had_reset     <= '0';
        had_start     <= '1';
        had_img       <= fft_out(0 to n_points/2);
        had_ker       <= ker_transf(0 to n_points/2);

      when latch_had =>
        fft_reset     <= '1';
        fft_start     <= '0';
        fft_clockwise <= '0';
        fft_in        <= slice_raster;
        had_reset     <= '0';
        had_start     <= '0';
        had_img       <= fft_out(0 to n_points/2);
        had_ker       <= ker_transf(0 to n_points/2);

      when ifft =>
        fft_reset     <= '0';
        fft_start     <= '1';
        fft_clockwise <= '1';
        fft_in        <= prod_sym;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when accumulate =>
        fft_reset     <= '0';
        fft_start     <= '0';
        fft_clockwise <= '1';
        fft_in        <= prod_sym;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when hold =>
        fft_reset     <= '0';
        fft_start     <= '0';
        fft_clockwise <= '1';
        fft_in        <= prod_sym;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when sl_reset =>
        fft_reset     <= '1';
        fft_start     <= '0';
        fft_clockwise <= '1';
        fft_in        <= prod_sym;
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));

      when others =>
        fft_reset     <= '1';
        fft_start     <= '0';
        fft_clockwise <= '0';
        fft_in        <= (others => (others => (others => '0')));
        had_reset     <= '1';
        had_start     <= '0';
        had_img       <= (others => (others => (others => '0')));
        had_ker       <= (others => (others => (others => '0')));
      end case;
  end process;

  res <= acc;

end architecture area_opt;


-- It's also possible to make a generic arch that builds x hecates using a process y times.


-- This arch is optimized on number of cycles. It uses parallel hecates and multiple FFTs    (WORK IN PROGRESS)
-- architecture time_opt of hecate is

--   constant hec_x : natural := ix/2;
--   constant hec_y : natural := iy/2;
--   constant hec_z : natural := iz/2;

--   signal ker_transf : t_signed_complex_array(0 to signed_point);
--   signal ready_ker  : std_logic;

--   signal trigger_arr : std_logic_vector(0 to hec_x*hec_y*hec_z-1);
--   signal trigger     : std_logic;
--   signal ready_arr   : std_logic_vector(0 to ox*oy*oz-1) := (others => '0');

--   type t_signed_4d_real_array is array (natural range <>) of t_signed_3d_real_array;
--   type t_signed_5d_real_array is array (natural range <>) of t_signed_4d_real_array;
--   type t_signed_6d_real_array is array (natural range <>) of t_signed_5d_real_array;
--   signal hec : t_signed_6d_real_array(0 to hec_z-1)(0 to hec_y-1)(0 to hec_x-1)(0 to 2)(0 to 2)(0 to 2);
  
-- begin

--   fft_in_ker : component fft
--   generic map (2, 2, 2, 32)
--   port map (
--     i       => ker,
--     o       => ker_transf,
--     clock   => clock,
--     start   => start,
--     reset   => reset,
--     s_ready => ready_ker
--   );

--   gen_hec_z : for hz in 0 to hec_z-1 generate
--     gen_hec_y : for hy in 0 to hec_y-1 generate
--       gen_hec_x : for hx in 0 to hec_x-1 generate
--         signal slice : t_signed_3d_real_array(0 to 1)(0 to 1)(0 to 1);
--       begin
--         slice <= (
--           ( ( img(hz*2  )(hy*2  )(hx*2  ),
--               img(hz*2  )(hy*2  )(hx*2+1)  ),
--             ( img(hz*2  )(hy*2+1)(hx*2  ),
--               img(hz*2  )(hy*2+1)(hx*2+1)  ) ),
--           ( ( img(hz*2+1)(hy*2  )(hx*2  ),
--               img(hz*2+1)(hy*2  )(hx*2+1)  ),
--           (   img(hz*2+1)(hy*2+1)(hx*2  ),
--               img(hz*2+1)(hy*2+1)(hx*2+1)  ) )
--         );
--         hec_slice : component hadamard_arr
--           port map (
--             img        => slice,
--             ker_transf => ker_transf,
--             ready_ker  => ready_ker,
--             clock      => clock,
--             reset      => reset,
--             start      => start,
--             res        => hec(hz)(hy)(hx),
--             o_ready    => trigger_arr(hz*hec_y*hec_x + hy*hec_x + hx)
--           );
--       end generate gen_hec_x;
--     end generate gen_hec_y;
--   end generate gen_hec_z;
--   trigger <= and(trigger_arr);

--   gen_oz : for g_oz in 0 to oz-1 generate
--     gen_oy : for g_oy in 0 to oy-1 generate
--       gen_ox : for g_ox in 0 to ox-1 generate
--         process (clock, reset) is
--           variable hec_idx : std_logic_vector(2 downto 0) := (others => '0');
--           variable hz, hy, hx : integer := 0;
--         begin
--           if rising_edge(clock) then
--             if (reset) then
--               res(g_oz)(g_oy)(g_ox) <= (others => '0');
--               ready_arr(g_oz*oy*ox + g_oy*ox + g_ox) <= '0';
--               hec_idx := (others => '0');
--             elsif(trigger and not ready_arr(g_oz*oy*ox + g_oy*ox + g_ox)) then
--               hz := to_integer(unsigned'('0' & hec_idx(2)));
--               hy := to_integer(unsigned'('0' & hec_idx(1)));
--               hx := to_integer(unsigned'('0' & hec_idx(0)));
--                 for sz in 0 to 2 loop
--                   for sy in 0 to 2 loop
--                     for sx in 0 to 2 loop
--                       if ((g_ox=hx*2+sx) and (g_oy=hy*2+sy) and (g_oz=hz*2+sz)) then
--                         res(g_oz)(g_oy)(g_ox) <= std_logic_vector(unsigned(res(g_oz)(g_oy)(g_ox)) + unsigned(hec(hz)(hy)(hx)(sz)(sy)(sx)));

--                         -- if ((g_oz=2) and (g_oy=2) and (g_ox=2)) then -- central point
--                         --   report "hec(" & integer'image(hz) & ")(" & integer'image(hy) & ")(" & integer'image(hx) & ")(" & integer'image(sz) & ")(" & integer'image(sy) & ")(" & integer'image(sx) & ") = " & integer'image(to_integer(unsigned(hec(hz)(hy)(hx)(sz)(sy)(sx))));
--                         -- end if;

--                       end if;
--                     end loop;
--                   end loop;
--                  end loop;
--               if hec_idx = "111" then
--                 ready_arr(g_oz*oy*ox + g_oy*ox + g_ox) <= '1';
--               else
--                 hec_idx := std_logic_vector(unsigned(hec_idx) + 1);
--               end if;
--             end if;
--           end if;
--         end process;
--       end generate gen_ox;
--     end generate gen_oy;
--   end generate gen_oz;
--   o_ready <= and(ready_arr);

-- end architecture time_opt;