  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
entity hecate_oa is
  port (
    img                 : in b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
    ker                 : in b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
    clock, reset, start : in std_logic;
    res                 : out b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
    ready               : out std_logic := '0'
  );
end entity hecate_oa;

-- It's also possible to make a generic arch that builds x hecates using a process y times.

-- This arch is optimized in terms of area. It uses 1 hecate and 1 fft
architecture area_opt of hecate_oa is

  constant slice_x            : natural := ix/kx;
  constant slice_y            : natural := iy/ky;
  constant slice_z            : natural := iz/kz;
  signal   sx, sy, sz         : natural := 0;

  signal acc                  : b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0')))); -- LATCH
  signal ker_transf           : b25_complex_array(0 to n_points/2); -- LATCH
  signal acc_ready, ker_ready : std_logic := '0'; -- LATCH

  signal fft_in               : b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1) := (others => (others => (others => (others => '0'))));
  signal fft_out              : b25_complex_array(0 to n_points/2);
  signal fft_start, fft_ready : std_logic := '0';
  signal fft_reset            : std_logic := '1';

  signal hec_img, hec_ker     : b25_complex_array(0 to n_points/2) := (others => (others => (others => '0')));
  signal hec_out, hec_acc     : b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
  signal hec_start, hec_ready : std_logic := '0';
  signal hec_reset            : std_logic := '1';

begin

  fft_single : component fft
    port map (
      i       => fft_in,
      o       => fft_out,
      clock   => clock,
      reset   => fft_reset,
      start   => fft_start,
      s_ready => fft_ready
    );
  
  hec_single : component hecate
    port map (
      img_transf => hec_img,
      ker_transf => hec_ker,
      clock      => clock,
      reset      => hec_reset,
      start      => hec_start,
      res        => hec_out,
      ready      => hec_ready
    );

  gen_oa_adds_z : for z in 0 to nz-1 generate
    gen_oa_adds_y : for y in 0 to ny-1 generate
      gen_oa_adds_x : for x in 0 to nx-1 generate
        signal temp_acc : std_logic_vector(24 downto 0);
      begin

        temp_acc <= acc(sz*kz+z)(sy*ky+y)(sx*kx+x);

        oa_add : component b25_add
          port map (
            a   => temp_acc,
            b   => hec_out(z)(y)(x),
            res => hec_acc(z)(y)(x)
          );

      end generate gen_oa_adds_x;
    end generate gen_oa_adds_y;
  end generate gen_oa_adds_z;

  proc_slice : process(clock) begin
    if rising_edge(clock) then
      if (reset or ready) then
        if reset then ready <= '0'; end if;
        sx <= 0; sy <= 0; sz <= 0;
        fft_reset <= '1'; hec_reset <= '1'; ker_ready <= '0'; acc_ready <= '0';
        acc <= (others => (others => (others => (others => '0'))));
        ker_transf <= (others => (others => (others => '0')));
      elsif (start) then

        if (not ker_ready) then -- Transform kernel
          if (not fft_ready) then
            fft_in <= ker; fft_start <= '1'; fft_reset <= '0';
            -- assignments are instructed to happen every cycle, but I don't see how this would infer more hardware than creating another IF
          else
            fft_start <= '0'; fft_reset <= '1';
            ker_ready <= '1'; ker_transf <= fft_out;
          end if;

        elsif (not fft_ready) then -- Transform slice
          for szi in 0 to kz-1 loop
            for syi in 0 to ky-1 loop
              for sxi in 0 to kx-1 loop
                fft_in(szi)(syi)(sxi) <= img(sz*kz+szi)(sy*ky+syi)(sx*kx+sxi);
              end loop;
            end loop;
          end loop;
          fft_start <= '1'; fft_reset <= '0';

        elsif (not hec_ready) then -- Start hecate
          hec_img <= fft_out; hec_ker <= ker_transf;
          hec_start <= '1'; hec_reset <= '0';
                
        elsif (not acc_ready) then -- Update accumulator
          for z in 0 to nz-1 loop
            for y in 0 to ny-1 loop
              for x in 0 to nx-1 loop
                acc(sz*kz+z)(sy*ky+y)(sx*kx+x) <= hec_acc(z)(y)(x);
              end loop;
            end loop;
          end loop;
          acc_ready <= '1';

        else -- Next slice / finish
          fft_start <= '0'; fft_reset <= '1';
          hec_start <= '0'; hec_reset <= '1';
          acc_ready <= '0';
          sx <= sx + 1;
          if (sx+1 >= slice_x) then
            sy <= sy + 1; sx <= 0;
            if (sy+1 >= slice_y) then
              sz <= sz + 1; sy <= 0;
              if (sz+1 >= slice_z) then
                sz <= 0;
                ready <= '1';
              end if;
            end if;
          end if;

        end if;
      end if;
    end if;
  end process proc_slice;
  res <= acc;

end architecture area_opt;
















-- This arch is optimized on number of cycles. It uses parallel hecates and multiple FFTs.    (WORK IN PROGRESS)
-- architecture time_opt of hecate_oa is

--   constant hec_x : natural := ix/2;
--   constant hec_y : natural := iy/2;
--   constant hec_z : natural := iz/2;

--   signal ker_transf : b25_complex_array(0 to 16);
--   signal ready_ker  : std_logic;

--   signal trigger_arr : std_logic_vector(0 to hec_x*hec_y*hec_z-1);
--   signal trigger     : std_logic;
--   signal ready_arr   : std_logic_vector(0 to ox*oy*oz-1) := (others => '0');

--   type b25_4d_real_array is array (natural range <>) of b25_3d_real_array;
--   type b25_5d_real_array is array (natural range <>) of b25_4d_real_array;
--   type b25_6d_real_array is array (natural range <>) of b25_5d_real_array;
--   signal hec : b25_6d_real_array(0 to hec_z-1)(0 to hec_y-1)(0 to hec_x-1)(0 to 2)(0 to 2)(0 to 2);
  
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
--         signal slice : b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
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
--         hec_slice : component hecate
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