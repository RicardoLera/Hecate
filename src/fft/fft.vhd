  use work.hecate_pkg.all;
  use work.fft_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

-- Note: this FFT returns the complex conjugate compared to cor.py. It's a matter twiddle factor selection (counterclockwise vs clockwise) and it cancels out in the IDFT, but it's worth noting
entity fft is
  generic (
    nx, ny, nz : natural range 0 to 16 := 2;
    n_points   : natural range 0 to 1024 := 32
  );
  port (
    i                   : in  b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
    o                   : out b25_complex_array(0 to n_points/2);
    clock, reset, start : in  std_logic;
    s_ready             : out std_logic
  );
end entity fft;

architecture synth of fft is

  constant the_log : integer := integer(ceil(log2(real(n_points))));
  signal state     : integer range 0 to the_log+1 := 0; -- state 1 is synchronous start

  signal in_raster, in_scramble : b25_real_array(0 to n_points-1) := (others => (others => '0'));
  signal bfly_in, bfly_out      : b25_2d_complex_array(0 to n_points/2-1)(0 to 1) := (others => (others => (others => (others => '0')))); -- 0-top; 1-bottom
  signal wmul_in, wmul_out      : b25_2d_complex_array(0 to n_points/2-1)(0 to n_points/4-1) := (others => (others => (others => (others => '0'))));
  signal out_buff               : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

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
  
  gen_wmul4 : for m in 0 to n_points/4-1 generate -- to cover, e.g., w8 for N=32, of which there are a maximum of 7 instances active at once
    wmul_out(n_points/4)(m) <= (                                                    -- (a + bi)*i = 
    ((not wmul_in(n_points/4)(m)(1)(24)) & wmul_in(n_points/4)(m)(1)(23 downto 0)), -- -b
    wmul_in(n_points/4)(m)(0)                                                       -- +ai
    );
  end generate gen_wmul4;

  wmul_out(0) <= wmul_in(0);

  -- State machine
  state_machine : process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        state <= 0;
      elsif (start) then
        if (state < the_log+1) then
          state <= state + 1;
        end if;
      end if;
    end if;
  end process state_machine;

  -- Input Layer (rasterize and scramble)
  gen_z : for z in 0 to nz-1 generate
    gen_y : for y in 0 to ny-1 generate
      gen_x : for x in 0 to nx-1 generate
        constant nx_full : integer := 2*nx-1;
        constant ny_full : integer := 2*ny-1;
        constant n       : integer := x + y*nx_full + z*nx_full*ny_full;
      begin
        in_raster(n) <= i(z)(y)(x);
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

  gen_n : for n in 0 to n_points-1 generate
    in_scramble(scramble_lut(n)) <= in_raster(n);
  end generate gen_n;

  -- MUX Arrays         NOT GENERIC - Fully generic requires concatenating 1-bit muxes
  gen_mux_bfly1 : for b in 0 to n_points/2-1 generate
    gen_mux_bfly2 : for tb in 0 to 1 generate
      signal bfly_in_reg : b25_complex := (others => (others => '0'));
    begin

      latch_bfly_in_reg : process (state) is
        variable n : integer;
      begin
        if (state > 1) and (state < the_log+1) then
          n := bfly_idx_rev(state, b, tb);
          case (wmul_idx(state-1, n)(2)) is
            when 1      => bfly_in_reg <= wmul_out(wmul_idx(state-1, n)(0))(wmul_idx(state-1, n)(1));
            when others => bfly_in_reg <= bfly_out(bfly_idx(state-1, n)(0))(bfly_idx(state-1, n)(1));
          end case;
        end if;
      end process latch_bfly_in_reg;

      with state select bfly_in(b)(tb) <=
        (others => (others => '0')) when 0,
        (in_scramble(bfly_idx_rev(1, b, tb)), 25b"0") when 1,
        bfly_in_reg when others;

    end generate gen_mux_bfly2;
  end generate gen_mux_bfly1;

  gen_mux_wmul1 : for w in 0 to n_points/2-1 generate
    gen_mux_wmul2 : for m in 0 to n_points/4-1 generate
      signal wmul_in_sel : b25_complex_array(1 to the_log-1);
    begin

      gen_sel_wmul : for s in 1 to (the_log-1) generate
        constant n : integer := wmul_idx_rev(s, w, m);
      begin
        with (wmul_lut(s)(n) = (w,m,1)) select wmul_in_sel(s) <=
          bfly_out(bfly_lut(s)(n)(0))(bfly_lut(s)(n)(1)) when TRUE,
          (others => (others => '0')) when others;
      end generate gen_sel_wmul;

      with state select wmul_in(w)(m) <=
        (others => (others => '0')) when 0,
        wmul_in_sel(1) when 1,
        wmul_in_sel(2) when 2,
        wmul_in_sel(3) when 3,
        wmul_in_sel(4) when others;

    end generate gen_mux_wmul2;
  end generate gen_mux_wmul1;

  gen_procs_out : for n in 0 to n_points-1 generate
    constant b  : integer := n mod (n_points/2);
    constant tb : integer := n / (n_points/2);
  begin
    with state select out_buff(n) <=
      bfly_out(b)(tb) when 6,
      (others => (others => '0')) when others;
  end generate gen_procs_out;
  s_ready <= '1' when state=the_log+1 else '0';
  o <= out_buff(0 to n_points/2) when s_ready else (others => (others => (others => '0')));

end architecture synth;






























  -- -- Butterfly Layer
  -- -- This version of the bfly and wmul blocks scour the LUTs recursivelly, which is hope is optimized by the synthesizer
  -- -- Later attempt calling 'bfly_in(bfly_lut(state, n)(0))(bfly_lut(state, n)(1))' to see if the direct call is still interpreted as static and avoid lsp clashes
  -- gen_procs_bfly : for b in 0 to n_points/2-1 generate -- bfly_out(b)(tb)[b25C] <= in_scramble(n) | wmul_out(w)(m)(state)[b25C]
  --   gen_procs_bfly_tb : for tb in 0 to 1 generate
  --     -- signal n : integer;
  --   begin

  --     -- n <= bfly_lut_rev(state, b, tb) when ((state > 0) and (state < the_log)) else 0;
  --     -- bfly_in(b)(tb) <=
  --     --   (others => (others => '0'))
  --     --     when (reset = '1') else
  --     --   (in_scramble(n), 25b"0")
  --     --     when (state = 1) else
  --     --   wmul_out(wmul_lut(state-1, n)(0))(wmul_lut(state-1, n)(1))
  --     --     when ((state > 0) and (state < the_log+1) and (wmul_lut(state-1, n)(2) /= 0)) else
  --     --   bfly_out(bfly_lut(state-1, n)(0))(bfly_lut(state-1, n)(1))
  --     --     when ((state > 0) and (state < the_log+1) and (wmul_lut(state-1, n)(2) = 0)) else
  --     --   (others => (others => '0'));

  --       -- infers latches
  --     proc_bfly : process (state) is
  --       variable n : integer;
  --     begin
  --       if (reset) then
  --         bfly_in(b)(tb) <= (others => (others => '0'));

  --       elsif (state > 0) and (state < the_log+1) then
  --         n := bfly_lut_rev(state, b, tb);
  --         if (state = 1) then
  --           --report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb);
  --           bfly_in(b)(tb) <= (in_scramble(n), 25b"0");
  --         else
  --           if (wmul_lut(state-1, n)(2) /= 0) then -- verifies if there is a corresponding multiplier
  --             bfly_in(b)(tb) <= wmul_out(wmul_lut(state-1, n)(0))(wmul_lut(state-1, n)(1));
  --           else
  --             bfly_in(b)(tb) <= bfly_out(bfly_lut(state-1, n)(0))(bfly_lut(state-1, n)(1));
  --           end if;
  --         end if;
  --       end if;
  --     end process proc_bfly;

  --   end generate gen_procs_bfly_tb;
  -- end generate gen_procs_bfly;

  -- -- Complex Multiplier Layer
  -- gen_procs_wmul : for w in 0 to n_points/2-1 generate -- wmul_in(w)(m)(state)[b25C] <= bfly_out(b)(tb)[b25C]
  --   gen_procs_wmul2 : for m in 0 to n_points/4-1 generate
  --     signal n, b, tb : integer;
  --   begin

  --     n  <= wmul_lut_rev(state, w, m) when ((state > 0) and (state < the_log)) else 0;
  --     b  <= bfly_lut(state, n)(0) when ((state > 0) and (state < the_log) and (wmul_lut(state, n) = (w,m,1))) else 0;
  --     tb <= bfly_lut(state, n)(1) when ((state > 0) and (state < the_log) and (wmul_lut(state, n) = (w,m,1))) else 0;
  --     wmul_in(w)(m) <=
  --       (others => (others => '0'))
  --         when (reset = '1') else
  --       bfly_out(b)(tb)
  --         when ((state > 0) and (state < the_log) and (wmul_lut(state, n) = (w,m,1))) else
  --       (others => (others => '0'));

  --       -- infers latches
  --     -- subcycle_trigger(w)(m) <=
  --     --   bfly_out(bfly_lut(state, wmul_lut_rev(state,w,m))(0))(bfly_lut(state, wmul_lut_rev(state,w,m))(1))
  --     --     when (state > 0) and (state < the_log) else
  --     --   (25b"1", 25b"0")    -- Trigger all processes when reset=1, so they can be reset
  --     --     when (reset = '1') else
  --     --   (others => (others => '0'));

  --     -- proc_wmul : process (subcycle_trigger(w)(m)) is
  --     --   variable b, tb, n : integer;
  --     -- begin
  --     --   if (reset) then
  --     --     wmul_in(w)(m) <= (others => (others => '0'));

  --     --   elsif ((state > 0) and (state < the_log)) then
  --     --     n  := wmul_lut_rev(state, w, m);
  --     --     if ((wmul_lut(state, n) = (w,m,1))) then
  --     --       b  := bfly_lut(state, n)(0);
  --     --       tb := bfly_lut(state, n)(1);
  --     --       --report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) & "   w = " & integer'image(w) & "   m = " & integer'image(m);
  --     --       wmul_in(w)(m) <= bfly_out(b)(tb);
  --     --     end if;
  --     --   end if;
  --     -- end process proc_wmul;

  --   end generate gen_procs_wmul2;
  -- end generate gen_procs_wmul;

  -- -- Output Layer
  -- s_ready <= '1' when state=the_log+1 else '0';
  -- gen_procs_out : for n in 0 to n_points-1 generate
  --   out_buff(n) <=
  --     (others => (others => '0'))
  --       when (state /= the_log+1) else
  --     bfly_out(n mod (n_points/2))(0)
  --       when (n < n_points/2) else
  --     bfly_out(n mod (n_points/2))(1);
  --   -- full N buffer is meant for debugging, but it's not a lot of hardware so I'll leave it

  --     -- infers latches
  --   -- proc_out : process (state)
  --   -- begin
  --   --   if (state = the_log+1) then
  --   --     if (n < n_points/2) then -- top/bottom
  --   --       out_buff(n) <= bfly_out(n)(0);
  --   --     else
  --   --       out_buff(n) <= bfly_out(n mod (n_points/2))(1);
  --   --     end if;
  --   --   end if;
  --   -- end process proc_out;
  -- end generate gen_procs_out;
  -- o <= out_buff(0 to n_points/2) when s_ready else (others => (others => (others => '0')));