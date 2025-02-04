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

  signal state   : integer range 0 to the_log+1 := 0; -- state 1 is synchronous start
  signal sc_link : std_logic_vector(0 to n_points-1) := (others => '0');
  signal link_trigger : std_logic := '0';

  signal in_raster : b25_real_array(0 to n_points-1) := (others => (others => '0'));
  signal bfly_in, bfly_out : b25_2d_complex_array(0 to n_points/2-1)(0 to 1) ; -- 0-top; 1-bottom
  signal wmul_in, wmul_out : b25_2d_complex_array(0 to n_points/4)(0 to the_log) := (others => (others => (others => (others => '0'))));
  signal out_buff : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

  function fft_scramble_lut(x, y, z : integer) return integer is
    variable idx     : integer := 0;
    constant nx_full : integer := 2*nx-1;
    constant ny_full : integer := 2*ny-1;
    constant n       : integer := x + y*nx_full + z*nx_full*ny_full;
  begin
    for g in 0 to the_log-1 loop
      if (n mod (2**(g+1)) >= 2**g) then
        idx := idx + n_points / (2**(g+1));
      end if;
    end loop;
    return idx;
  end function;

  type integer_pair is array(0 to 1) of integer;

   -- bfly_lut converts n to the order the butterflies are at, top to bottom, in their respective state
  function bfly_lut(s, n : integer) return integer_pair is
    variable points_in_group, bflys_in_group, current_group, index_in_group, b, tb : integer;
  begin
    if (s = 0) then
      return (0,0);
    else
      points_in_group       := 2**s;
      bflys_in_group        := 2**(s-1);

      current_group    := n / points_in_group;
      index_in_group   := n mod bflys_in_group;

      b := current_group * bflys_in_group + index_in_group;
      if ((n mod points_in_group) < bflys_in_group) then
        tb := 1;
      else
        tb := 0;
      end if;
      
      return (b, tb);
    end if;
  end function;

  function wmul_lut(stage, n : integer) return integer_pair is
    variable w, mn : integer := 0;
  begin
    --The "Table"
    return (w, mn);
  end function;

begin

  -- Rasterize and scramble input
  gen_x : for x in 0 to nx-1 generate
    gen_y : for y in 0 to ny-1 generate
      gen_z : for z in 0 to nz-1 generate
        in_raster(fft_scramble_lut(x, y, z)) <= i(x)(y)(z);
      end generate gen_z;
    end generate gen_y;
  end generate gen_x;

  -- Generate butterflies
  gen_bfly : for b in 0 to n_points/2-1 generate

    bfly : component b25_butterfly
      port map (
        i_top => bfly_in(b)(0),
        i_bot => bfly_in(b)(1),
        o_top => bfly_out(b)(0),
        o_bot => bfly_out(b)(1)
      );

  end generate gen_bfly;

  -- Generate complex constant multiplers
  gen_wmul : for w in 1 to n_points/4 generate
    gen_wmul_loop : for mn in 0 to the_log generate
      gen_wmul_check : if (w mod (2**mn) = 0) generate

        wmul : component b25_wmul
          generic map (
            w => w,
            n => n_points
          )
          port map (
            i => wmul_in(w)(mn),
            o => wmul_out(w)(mn)
          );

      end generate gen_wmul_check;
    end generate gen_wmul_loop;
  end generate gen_wmul;
  wmul_out(0) <= wmul_in(0);

  -- State machine
  state_machine : process (clock) begin
    if rising_edge(clock) then

      if (reset) then
        state <= 0;
        sc_link <= (others => '0');
        s_ready <= '0';

      elsif (start) then
        if (state < the_log+1) then
          state <= state + 1;
          sc_link <= (others => '0');
        else
          s_ready <= '1';
        end if;
      end if;
      
    end if;
  end process state_machine;

  -- Subcycle 1: Butterflies
  gen_procs_bfly : for n in 0 to n_points-1 generate
    proc_bfly : process (state) is
      variable b, tb, w, mn, w_mod : integer;
    begin

      if (state > 0) then
        b  := bfly_lut(state, n)(0);
        tb := bfly_lut(state, n)(1);
        w  := wmul_lut(state-1, n)(0);
        mn := wmul_lut(state-1, n)(1);
        w_mod := w mod n_points/4;

        if (state < the_log) then
          if (state < 1) then
            bfly_in(b)(tb) <= (in_raster(n), 25b"0");
          else
            bfly_in(b)(tb) <= wmul_out(w_mod)(mn);
          end if;
        else
          if (n < n_points/2) then
            out_buff(n) <= bfly_in(n)(0);
          else
            out_buff(n) <= bfly_in(n mod n_points/2)(1);
          end if;
        end if;
      end if;

    end process proc_bfly;
  end generate gen_procs_bfly;
  o <= out_buff(0 to 16);

  -- Subcycle link
  gen_link_b : for b in 0 to n_points/2-1 generate
    process(bfly_out(b)(0)) begin
      sc_link(b) <= '1';
    end process;
  end generate gen_link_b;
  link_trigger <= and(sc_link);

  -- Subcycle 2: Omega Multipliers
  gen_procs_wmul : for n in 0 to n_points-1 generate
    proc_wmul : process (link_trigger) is
      constant b     : integer := bfly_lut(state, n)(0);
      constant tb    : integer := bfly_lut(state, n)(1);
      constant w     : integer := wmul_lut(state, n)(0);
      constant mn    : integer := wmul_lut(state, n)(1);
      constant w_mod : integer := w mod n_points/4;
    begin

      if (w >= n_points/4) then -- multiply by i (because, e.g., w1 = i*w9)
        wmul_in(w_mod)(mn) <= (                              -- (a + bi)*i = 
          (not bfly_out(b)(tb)(1)(24) & bfly_out(b)(tb)(1)), -- -b
          bfly_out(b)(tb)(0)                                 -- +ai
        );
      else
        wmul_in(w_mod)(mn) <= bfly_out(b)(tb);
      end if;

    end process proc_wmul;
  end generate gen_procs_wmul;

end architecture synth;































  -- Behavior
  -- proc_wmul : process (op_sel) is
  --   constant b_size     : integer := 2**to_integer(state/2) + 1;
  --   constant group_size : integer := 2**to_integer(state/2);
  --   variable group_idx  : integer;
  --   variable b_position : integer;
  --   variable w_idx      : integer;
  --   variable wmul_xcor  : integer;
  --   constant wmul_ycor  : integer := the_log - to_integer(state/2);
  -- begin

  --   -- Butterfly
  --   if op_sel = '0' then
  --     if (state < cycles-1) then
  --       for b in 0 to n_points/2-1 loop
  --         if (state /= 0) then
  --           wmul_xcor := (w_idx mod n_points/4)-1;
  --           bfly_raster(b_position) <= wmul_out(wmul_ycor)(wmul_xcor);
  --         end if;
    
  --         bfly_in_top(b) <= bfly_raster(b_position);
  --         bfly_in_bot(b) <= bfly_raster(b_position + b_size);
  --       end loop;
  --       else
  --       for b in 0 to n_points/2-1 loop
  --         if (b = 0) then
  --           out_buff(n_points/2) <= bfly_in_bot(0); -- Hermitian limit
  --         end if;
  --         out_buff(b) <= bfly_in_top(b);
  --       end loop;
  --     end if;


  --   -- Omega Multipliers
  --   else
  --     if (state < cycles-1) then
  --       for p in 0 to n_points-1 loop
  --         group_idx  := p/(2*group_size);
  --         b_position := group_size*group_idx + (p mod group_size);
  
  --         -- Update raster
  --         if (p mod b_size < b_size/2) then -- top
  --           wmul_raster(p) <= bfly_out_top(b_position);
  --         else -- bottom
  --           wmul_raster(p) <= bfly_out_bot(b_position);
  --         end if;

  --         -- Feed cmuls
  --         if (group_idx mod 2 = 1) then -- every second bfly group
  --           w_idx := (p mod group_size*2) * (2**to_integer(n_points/4 - state));

  --           if (w_idx /= 0) then
  --             wmul_xcor := (w_idx mod n_points/4)-1;
  --             wmul_in(wmul_ycor)(wmul_xcor) <= wmul_raster(p);

  --             if (w_idx >= n_points/4) then -- multiply by i (because, e.g., w1 = i*w9)
  --               wmul_in(wmul_ycor)(wmul_xcor) <= (
  --                 (not wmul_in(wmul_ycor)(wmul_xcor)(1)(24) & wmul_in(wmul_ycor)(wmul_xcor)(1)),
  --                 wmul_in(wmul_ycor)(wmul_xcor)(0)
  --               );
  --             end if;

  --           end if;

  --         end if;
  --       end loop;
  --     end if;
  --   end if;

  -- end process proc_wmul;










































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




