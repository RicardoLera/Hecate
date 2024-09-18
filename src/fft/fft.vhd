library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity fft is
  generic (
    nx, ny, nz : natural range 0 to 16 := 2;
    n_points   : natural range 0 to 1024 := 32
  );
  port (
    i                   : in  b25_3d_real_array(0 to nx-1)(0 to ny-1)(0 to nz-1);
    o                   : out b25_complex_array(0 to n_points/2);
    clock, reset, start : in  std_logic;
    s_ready             : out std_logic
  );
end entity fft;

architecture synth of fft is

  --variable n_muls : natural range 0 to 2056 := 2*(n_points-6)-1;

  constant the_log : integer := integer(ceil(log2(real(n_points))));
  constant cycles  : integer := 2 * the_log - 1;

  signal state  : unsigned(integer(ceil(log2(real(cycles))))-1 downto 0) := (others => '0');
  signal op_sel : std_logic := '0'; -- 1 for bfly, 0 for wmul

  signal in_raster : b25_real_array(0 to n_points-1)    := (others => (others => '0'));
  signal bfly_raster, wmul_raster : b25_complex_array(0 to n_points-1);

  signal bfly_in_top, bfly_in_bot, bfly_out_top, bfly_out_bot : b25_complex_array(0 to n_points/2-1);

  type b25_2d_complex_array is array(0 to the_log) of b25_complex_array(0 to n_points/4-1);
  signal wmul_in, wmul_out : b25_2d_complex_array := (others => (others => (others => (others => '0'))));

  signal out_buff  : b25_complex_array(0 to n_points/2) := (others => (others => (others => '0')));

  -- This approach could increase the longest silicon path
  -- signal fly_done : std_logic_vector (0 to n_points/2-1) := (others => '0');
  -- signal mul_done : std_logic_vector (0 to n_points/4-2) := (others => '0');
  -- signal fly_done_all, mul_done_all : std_logic := '0';

  -- signal wmul_in_a, wmul_out_a : b25_complex_array(0 to n_points/4-2);
  -- signal wmul_in_b, wmul_out_b : b25_complex_array(0 to n_points/4-2);
  -- signal wmul_in_c, wmul_out_c : b25_complex_array(0 to n_points/4-2);
  -- signal wmul_in_d, wmul_out_d : b25_complex_array(0 to n_points/4-2);
  -- signal wmul_in_s, wmul_out_s : b25_complex_array(0 to 1);

  function FFT_scramble(x, y, z : integer) return integer is
    variable idx     : integer := 0;
    constant nx_full : integer := 2*nx-1;
    constant ny_full : integer := 2*ny-1;
    constant N       : integer := x + y*nx_full + z*nx_full*ny_full;
  begin
    for g in 0 to cycles-1 loop
      if(N mod 2**(g+1) >= 2**g) then
        idx := idx + n_points / 2**(g+1);
      end if;
    end loop;
    return idx;
  end function;

begin

  -- Rasterize and scramble
  gen_x : for x in 0 to nx-1 generate
    gen_y : for y in 0 to ny-1 generate
      gen_z : for z in 0 to nz-1 generate
        in_raster(FFT_scramble(x, y, z)) <= i(x)(y)(z);
      end generate gen_z;
    end generate gen_y;
  end generate gen_x;

  -- Generate butterflies
  gen_bfly : for b in 0 to n_points/2-1 generate

    bfly : component b25_butterfly
      port map (
        i_top => bfly_in_top(b),
        i_bot => bfly_in_bot(b),
        o_top => bfly_out_top(b),
        o_bot => bfly_out_bot(b)
      );

  end generate gen_bfly;
  o <= out_buff;

  -- Generate complex constant multiplers
  gen_wmul : for n in 1 to n_points/4 generate
    gen_wmul_loop : for l in 0 to the_log generate
      gen_wmul_check : if (n mod (2**l) = 0) generate

        wmul : component b25_wmul
          generic map (
            w => n,
            n => n_points
          )
          port map (
            i => wmul_in(l)(n-1),
            o => wmul_out(l)(n-1)
          );

      end generate gen_wmul_check;
    end generate gen_wmul_loop;
  end generate gen_wmul;

  -- State machine
  state_machine : process (clock) begin
    if rising_edge(clock) then

      if (reset) then
        state <= (others => '0');
        s_ready <= '0';
        op_sel <= '0';
        for b in 0 to n_points-1 loop
          bfly_raster(b) <= (in_raster(b), 25b"0");
        end loop;

      elsif (start) then
        if (state < cycles) then
          op_sel <= not op_sel;
          state <= state + 1;
        else
          s_ready <= '1';
        end if;
      end if;
      
    end if;
  end process state_machine;

  -- Behavior
  proc_wmul : process (op_sel) is
    constant b_size     : integer := 2**to_integer(state/2) + 1;
    constant group_size : integer := 2**to_integer(state/2);
    variable group_idx  : integer;
    variable b_position : integer;
    variable w_idx      : integer;
    variable wmul_xcor  : integer;
    constant wmul_ycor  : integer := the_log - to_integer(state/2);
  begin

    -- Butterfly
    if op_sel = '0' then
      if (state < cycles-1) then
        for b in 0 to n_points/2-1 loop
          if (state /= 0) then
            wmul_xcor := (w_idx mod n_points/4)-1;
            bfly_raster(b_position) <= wmul_out(wmul_ycor)(wmul_xcor);
          end if;
    
          bfly_in_top(b) <= bfly_raster(b_position);
          bfly_in_bot(b) <= bfly_raster(b_position + b_size);
        end loop;
        else
        for b in 0 to n_points/2-1 loop
          if (b = 0) then
            out_buff(n_points/2) <= bfly_in_bot(0); -- Hermitian limit
          end if;
          out_buff(b) <= bfly_in_top(b);
        end loop;
      end if;


    -- Omega Multipliers
    else
      if (state < cycles-1) then
        for p in 0 to n_points-1 loop
          group_idx  := p/(2*group_size);
          b_position := group_size*group_idx + (p mod group_size);
  
          -- Update raster
          if (p mod b_size < b_size/2) then -- top
            wmul_raster(p) <= bfly_out_top(b_position);
          else -- bottom
            wmul_raster(p) <= bfly_out_bot(b_position);
          end if;

          -- Feed cmuls
          if (group_idx mod 2 = 1) then -- every second bfly group
            w_idx := (p mod group_size*2) * (2**to_integer(n_points/4 - state));

            if (w_idx /= 0) then
              wmul_xcor := (w_idx mod n_points/4)-1;
              wmul_in(wmul_ycor)(wmul_xcor) <= wmul_raster(p);

              if (w_idx >= n_points/4) then -- multiply by i (because, e.g., w1 = i*w9)
                wmul_in(wmul_ycor)(wmul_xcor) <= (
                  (not wmul_in(wmul_ycor)(wmul_xcor)(1)(24) & wmul_in(wmul_ycor)(wmul_xcor)(1)),
                  wmul_in(wmul_ycor)(wmul_xcor)(0)
                );
              end if;

            end if;

          end if;
        end loop;
      end if;
    end if;

  end process proc_wmul;

end architecture synth;







    -- check_wsym : if (k = n_points/8-1) generate

    --   gen_wsym : for g in 0 to 1 generate
    --     wmul_wsym : component b25_wmul
    --       generic map (
    --         w => k,
    --         n => n_points
    --       )
    --       port map (
    --         i => wmul_in_s(g),
    --         o => wmul_out_s(g)
    --       );
    --   end generate gen_wsym;
      
    -- else generate
    --   wmul_a : component b25_wmul
    --     generic map (
    --       w => k,
    --       n => n_points
    --     )
    --     port map (
    --       i => wmul_in_a(k),
    --       o => wmul_out_a(k)
    --     );

    --   wmul_b : component b25_wmul
    --     generic map (
    --       w => k,
    --       n => n_points
    --     )
    --     port map (
    --       i => wmul_in_b(k),
    --       o => wmul_out_b(k)
    --     );

    --   wmul_c : component b25_wmul
    --     generic map (
    --       w => k,
    --       n => n_points
    --     )
    --     port map (
    --       i => wmul_in_c(k),
    --       o => wmul_out_c(k)
    --     );

    --   wmul_d : component b25_wmul
    --     generic map (
    --       w => k,
    --       n => n_points
    --     )
    --     port map (
    --       i => wmul_in_d(k),
    --       o => wmul_out_d(k)
    --     );

    -- end generate check_wsym;


















    -- proc_bfly : process (op_sel) is
    --   constant b_size     : integer := 2**to_integer(state) + 1;
    --   constant group_size : integer := 2**to_integer(state);
    --   constant group_idx  : integer := b/group_size;
    --   constant b_position : integer := group_size*group_idx + (b mod group_size);
    -- begin

    --   if op_sel = '1' then
    --     if (state < cycles-1) then
    --       if (state /= 0) then
    --         bfly_raster(b_position) <= wmul_out
    --       end if;

    --       bfly_in_top(b) <= bfly_raster(b_position);
    --       bfly_in_bot(b) <= bfly_raster(b_position + b_size);
    --     else
    --       if (b = 0) then
    --         out_buff(n_points/2) <= bfly_in_bot(0); -- Hermitian limit
    --       end if;
    --       out_buff(b) <= bfly_in_top(b);
    --     end if;
    --   end if;

    -- end process proc_bfly;