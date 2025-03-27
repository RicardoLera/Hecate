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

  type integer_pair is array(0 to 1) of integer;
  type integer_trio is array(0 to 2) of integer;

  constant the_log         : integer := integer(ceil(log2(real(n_points))));
  signal state             : integer range 0 to the_log+1 := 0; -- state 1 is synchronous start

  signal in_raster         : b25_real_array(0 to n_points-1) := (others => (others => '0'));
  signal bfly_in, bfly_out : b25_2d_complex_array(0 to n_points/2-1)(0 to 1) := (others => (others => (others => (others => '0')))); -- 0-top; 1-bottom
  signal wmul_in, wmul_out : b25_2d_complex_array(0 to n_points/2-1)(0 to n_points/2-1) := (others => (others => (others => (others => '0'))));
  signal out_buff         : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

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

  -- bfly_lut converts n to the order the butterflies are at, top to bottom, in their respective state
  function bfly_lut(s, n : integer) return integer_pair is
    constant b : integer := (n/(2**s)) * (2**(s-1)) + (n mod (2**(s-1))); -- bfly_pos = bfly_group*group_size + pos_in_group
    -- Yes, (n/(2**s)) * (2**(s-1)) = n/2, except NOT because rounding. Leave it like that, it's synth time
    constant tb : boolean := not (n mod (2**s) < 2**(s-1));
  begin
    if ((s < 1) or (s > the_log)) then
      return (0,0);
    else
      --report "Inside bfly_lut: s = " & integer'image(s) & "   n = " & integer'image(n) & "   b = " & integer'image(b);
      if (tb) then
        return (b,1);
      else
        return (b,0);
      end if;
    end if;
  end function;

  -- bfly_lut_rev converts (b, tb) back to n, in their respective state
  function bfly_lut_rev(s, b, tb : integer) return integer is
    constant group_size   : integer := (2**(s-1));
    constant group_idx    : integer := b/group_size;
    constant pos_in_group : integer := b mod group_size;
    constant n : integer := 2*group_size*group_idx + pos_in_group + group_size*tb;
  begin
    if ((s < 1) or (s > the_log)) then
      return 0;
    else
      return n;
    end if;
  end function;
  
  -- wmul_lut converts n to the respective w multipliers, in their respective state, or returns (0,0,1) if no multiplication is needed
  function wmul_lut(s, n : integer) return integer_trio is
    constant valid : boolean := not (n mod (2**(s+1)) < 2**s); -- it's tb for the next state. I hate/love Fourier symmetry
    constant w : integer := (n mod (2**s)) * (2**(the_log-s-1)); -- pos_in_group (next state) times decreasing constant (2**(the_log-s-1))
    constant m : integer := (n/(2**(s+1))) ; -- group_idx = n/g_size[points]
  begin
    if ((s < 1) or (s > the_log-1) or not valid) then
      return (0,0,1);
    else
      --if (n mod (2**s)) >= (2**(s-1)) then 
        --return (w,m+1,0);
      --else
        return (w,m,0);
      --end if;
    end if;
  end function;

  -- wmul_lut_rev converts (w, m) back to n, in its respective state
  function wmul_lut_rev(s, w, m : integer) return integer is
    constant group_size   : integer := (2**s);
    constant pos_in_group : integer := w / (2**(the_log-s-1));
    constant group_idx    : integer := m;
    constant n : integer := 2*group_size*group_idx + pos_in_group + group_size;
  begin
    if ((s < 1) or (s > the_log-1) or (n > n_points-1)) then -- or (n mod (2**(s+1)) < 2**s) (invalid)
      return 0;
    else
      return n;
    end if;
  end function;

begin

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
  gen_wmul : for w in 1 to n_points/2-1 generate -- e.g., w1~w15 for N=32
    gen_wmul2 : for m in 0 to n_points/4-1 generate -- This can be further reduced with an if generate (previous: 2*factor2(n_points)-1)
      gen_wmul3 : if (w /= n_points/4) generate
        wmul : component b25_wmul
          generic map (
            w => w,
            n => n_points
          )
          port map (
            i => wmul_in(w)(m),
            o => wmul_out(w)(m)
          );
      end generate gen_wmul3;
    end generate gen_wmul2;
  end generate gen_wmul;
  gen_wmul4 : for m in 0 to n_points/2-1 generate -- to cover, e.g., w8 for N=32, of which there are 15 instances
    wmul_out(n_points/4)(m) <= (                                                  -- (a + bi)*i = 
    (not wmul_in(n_points/4)(m)(1)(24) & wmul_in(n_points/4)(m)(1)(23 downto 0)), -- -b
    wmul_in(n_points/4)(m)(0)                                                     -- +ai
    );
  end generate gen_wmul4;
  wmul_out(0) <= wmul_in(0);

  -- State machine
  state_machine : process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        state <= 0;
        s_ready <= '0';
      elsif (start) then
        if (state < the_log+1) then
          state <= state + 1;
        else
          s_ready <= '1';
        end if;
      end if;
    end if;
  end process state_machine;

    -- Input Layer (rasterize and scramble)
    gen_x : for x in 0 to nx-1 generate
      gen_y : for y in 0 to ny-1 generate
        gen_z : for z in 0 to nz-1 generate
          in_raster(fft_scramble_lut(x, y, z)) <= i(x)(y)(z);
        end generate gen_z;
      end generate gen_y;
    end generate gen_x;

  -- Butterfly Layer
  -- This version of the bfly and wmul blocks scour the LUTs recursivelly, which is hope is optimized by the synthesizer
  -- Later attempt calling 'bfly_in(bfly_lut(state, n)(0))(bfly_lut(state, n)(1))' to see if the direct call is still interpreted as static and avoid lsp clashes
  gen_procs_bfly : for b in 0 to n_points/2-1 generate -- bfly_out(b)(tb)[b25C] <= in_raster(n) | wmul_out(w)(m)(state)[b25C]
    gen_procs_bfly_tb : for tb in 0 to 1 generate
      proc_bfly : process (state) is
        variable n : integer;
      begin

        if (state > 0) and (state < the_log+1) then
          n := bfly_lut_rev(state, b, tb);
          if (state = 1) then
            --report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb);
            bfly_in(b)(tb) <= (in_raster(n), 25b"0");
          else
            if (wmul_lut(state-1, n) /= (0,0,1)) then -- verifies if there is a corresponding multiplier
              bfly_in(b)(tb) <= wmul_out(wmul_lut(state-1, n)(0))(wmul_lut(state-1, n)(1));
            else
              bfly_in(b)(tb) <= bfly_out(bfly_lut(state-1, n)(0))(bfly_lut(state-1, n)(1));
            end if;
          end if;
        end if;
        
      end process proc_bfly;
    end generate gen_procs_bfly_tb;
  end generate gen_procs_bfly;

  -- Complex Multiplier Layer
  gen_procs_wmul : for w in 0 to n_points/2-1 generate -- wmul_in(w)(m)(state)[b25C] <= bfly_out(b)(tb)[b25C]
    gen_procs_wmul2 : for m in 0 to n_points/2-1 generate
      signal trigger: b25_2d_complex_array(0 to n_points/2-1)(0 to n_points/2-1) := (others => (others => (others => (others => '0'))));
    begin
      trigger(w)(m) <=
        bfly_out(
          bfly_lut(
            state, wmul_lut_rev(state,w,m)
          )(0)
        )(
          bfly_lut(
            state, wmul_lut_rev(state,w,m)
          )(1)
        )
        when (state > 0) and (state < the_log) else (others => (others => '0'));
      proc_wmul : process (trigger(w)(m)) is
        variable b, tb, n : integer;
      begin
        if ((state > 0) and (state < the_log)) then
          n  := wmul_lut_rev(state,w,m);
          b  := bfly_lut(state, n)(0);
          tb := bfly_lut(state, n)(1);
          if (wmul_lut(state, n) /= (0,0,1)) then

            report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) & "   w = " & integer'image(w) & "   m = " & integer'image(m);
            wmul_in(w)(m) <= bfly_out(b)(tb);

          end if;
        end if;
      end process proc_wmul;
    end generate gen_procs_wmul2;
  end generate gen_procs_wmul;

  -- Output Layer
  gen_procs_out : for n in 0 to n_points-1 generate
    proc_out : process (state)
    begin
      if (state = the_log+1) then
        if (n < n_points/2) then -- top/bottom
          out_buff(n) <= bfly_out(n)(0);
        else
          out_buff(n) <= bfly_out(n mod n_points/2)(1);
        end if;
      end if;
    end process proc_out;
  end generate gen_procs_out;
  o <= out_buff(0 to n_points/2);

end architecture synth;