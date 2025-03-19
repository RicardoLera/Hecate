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

  constant the_log         : integer := integer(ceil(log2(real(n_points))));
  signal state             : integer range 0 to the_log+1 := 0; -- state 1 is synchronous start

  signal in_raster         : b25_real_array(0 to n_points-1) := (others => (others => '0'));
  signal bfly_in, bfly_out : b25_2d_complex_array(0 to n_points/2-1)(0 to 1) := (others => (others => (others => (others => '0')))); -- 0-top; 1-bottom
  signal wmul_in, wmul_out : b25_3d_complex_array(0 to n_points/4)(0 to n_points/4-1)(1 to the_log-1) := (others => (others => (others => (others => (others => '0')))));
  signal wmul_trigger, out_buff : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

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
  type integer_trio is array(0 to 2) of integer;

  -- bfly_lut converts n to the order the butterflies are at, top to bottom, in their respective state
  function bfly_lut(s, n : integer) return integer_pair is
    constant b : integer := (n/(2**s)) * (2**(s-1)) + (n mod (2**(s-1))); -- bfly_pos = bfly_group*group_size + pos_in_group
    -- Yes, (n/(2**s)) * (2**(s-1)) = n/2, except NOT because rounding. Leave it like that, it's synth time
    constant tb : boolean := not (n mod (2**s) < 2**(s-1));
  begin
    if ((s < 1) or (s > the_log)) then
      return (0,0);
    else
      if (tb) then
        return (b,1);
      else
        return (b,0);
      end if;
    end if;
  end function;

  -- wmul_lut converts n to the respective w multipliers, in their respective state, or returns (0,0,1) if no multiplication is needed
  function wmul_lut(s, n : integer) return integer_trio is
    constant valid : boolean := not (n mod (2**(s+1)) < 2**s); -- yes, it's tb for the next state. I hate/love Fourier symmetry
    constant w : integer := (n mod (2**s)) * (2**(the_log-s-1)); -- pos_in_group of the next state times decreasing constant (2**(the_log-s-1))
    constant m : integer := ((n/(2**(s+1))) mod (n_points/(2**(s+1)))); -- n's group index mod number_of_groups (next state)
  begin
    if ((s < 1) or (s > the_log-1) or not valid) then
      return (0,0,1);
    else
      if (w > n_points/4) then
        return (w - (w mod n_points/4),m,1);
      else
        return (w,m,0);
      end if;
    end if;
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
  gen_wmul : for w in 1 to n_points/4-1 generate -- e.g., w1~w7
    gen_wmul2 : for m in 0 to n_points/4-1 generate -- for each same w mul within the same state
      gen_wmul3 : for r in 1 to the_log-1 generate -- working backwards from last state
        gen_wmul_check : if (w mod (2**r) = 0) generate

          wmul : component b25_wmul
            generic map (
              w => w,
              n => n_points
            )
            port map (
              i => wmul_in(w)(m)(the_log-r),
              o => wmul_out(w)(m)(the_log-r)
            );

        end generate gen_wmul_check;
      end generate gen_wmul3;
    end generate gen_wmul2;
  end generate gen_wmul;
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

  -- This version of the bfly and wmul blocks scour the LUTs recursivelly, which is hope is optimized by the synthesizer
  -- Later attempt calling 'bfly_in(bfly_lut(state, n)(0))(bfly_lut(state, n)(1))' to see if the direct call is still interpreted as static and avoid driver clashes
  gen_procs_bfly : for b in 0 to n_points/2-1 generate -- bfly_out(b)(tb)[b25C] <= in_raster(n) | wmul_out(w)(m)(state)[b25C]
    gen_procs_bfly_tb : for tb in 0 to 1 generate
      proc_bfly : process (state) is
      begin
        for n in 0 to n_points-1 loop -- is n static? Otherwise out_buff is gonna clash
          if (state > 0) then
            if ((b = bfly_lut(state, n)(0)) and (tb = bfly_lut(state, n)(1))) then

              if (state < the_log) then
                if (state = 1) then
                  bfly_in(b)(tb) <= (in_raster(n), 25b"0");
                else
                  if (wmul_lut(state, n) = (0,0,1)) then -- verify if there is a corresponding multiplier
                    bfly_in(b)(tb) <= wmul_out(wmul_lut(state, n)(0))(wmul_lut(state, n)(1))(state);
                  else
                    bfly_in(b)(tb) <= bfly_out(bfly_lut(state, n)(0))(bfly_lut(state, n)(1));
                  end if;
                end if;
              else
                if (n < n_points/2) then -- top/bottom
                  out_buff(n) <= bfly_out(n)(0);
                else
                  out_buff(n) <= bfly_out(n mod n_points/2)(1);
                end if;
              end if;

            end if;
          end if;
        end loop;
      end process proc_bfly;
    end generate gen_procs_bfly_tb;
  end generate gen_procs_bfly;
  o <= out_buff(0 to n_points/2);

  gen_procs_wmul : for n in 0 to n_points-1 generate -- wmul_in(w)(m)(state)[b25C] <= bfly_out(b)(tb)[b25C]
    wmul_trigger(n) <= bfly_out(bfly_lut(state, n)(0))(bfly_lut(state, n)(1)) when state > 0  else (others => (others => '0'));
    proc_bfly : process (wmul_trigger(n)) is
      variable b, tb : integer;
    begin
      if ((state > 0) and (state < the_log)) then
        b  := bfly_lut(state, n)(0);
        tb := bfly_lut(state, n)(1);
        for w in 0 to 8 loop -- n_points/4
          for m in 0 to 7 loop -- n_points/4-1
            if ((w = wmul_lut(state, n)(0)) and (m = wmul_lut(state, n)(1)) and (wmul_lut(state, n) /= (0,0,1))) then

              if (wmul_lut(state, n)(2) = 1) then -- multiply by i (because, e.g., w1 = i*w9)
                report "i   state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) & "   w = " & integer'image(w) & "   m = " & integer'image(m);
                wmul_in(w)(m)(state) <= (                                         -- (a + bi)*i = 
                  (not bfly_out(b)(tb)(1)(24) & bfly_out(b)(tb)(1)(23 downto 0)), -- -b
                  bfly_out(b)(tb)(0)                                              -- +ai
                );
              else
                report "r   state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) & "   w = " & integer'image(w) & "   m = " & integer'image(m);
                wmul_in(w)(m)(1) <= bfly_out(b)(tb); -- lsp clash
              end if;

            end if;
          end loop;
        end loop;
      end if;
    end process proc_bfly;
  end generate gen_procs_wmul;

end architecture synth;