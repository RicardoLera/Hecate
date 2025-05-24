  use work.hecate_pkg.all;
  use work.fft_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

-- Note: this FFT returns the complex conjugate compared to cor.py. It's a matter twiddle factor selection (counterclockwise vs clockwise) and it cancels out in the IDFT, but it's worth noting
entity fft is
  port (
    i                   : in  b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
    o                   : out b25_complex_array(0 to n_points/2);
    clock, reset, start : in  std_logic;
    s_ready             : out std_logic
  );
end entity fft;

architecture synth of fft is

  signal state : integer range 0 to the_log+1 := 0; -- state 1 is synchronous start

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
    gen_wmul2 : for m in 0 to n_points/4-1 generate
      gen_wmul3 : if (w /= n_points/4) generate

        wmul_sel_loop : for s in 0 to the_log-2 generate
          wmul_sel_if : if ((w mod (2**s) = 0) and (m < 2**s)) generate 
              wmul : component b25_wmul
                generic map (w)
                port map (
                  i => wmul_in(w)(m),
                  o => wmul_out(w)(m)
                );
          end generate wmul_sel_if;
        end generate wmul_sel_loop;

      end generate gen_wmul3;
    end generate gen_wmul2;
  end generate gen_wmul;
  
  gen_wmul5 : for m in 0 to n_points/4-1 generate -- to cover, e.g., w8 for N=32, of which there are a maximum of 7 instances active at once
    wmul_out(n_points/4)(m) <= (                                                    -- (a + bi)*i = 
    ((not wmul_in(n_points/4)(m)(1)(24)) & wmul_in(n_points/4)(m)(1)(23 downto 0)), -- -b
    wmul_in(n_points/4)(m)(0)                                                       -- +ai
    );
  end generate gen_wmul5;

  wmul_out(0) <= wmul_in(0);

  -- State machine
  state_machine : process (clock) begin
    if (reset) then
      state <= 0;
    elsif rising_edge(clock) then
      if (start) then
        if (state < the_log+1) then
          state <= state + 1;
        end if;
      end if;
    end if;
  end process state_machine;

  -- Input Layer (rasterize and scramble)
  gen_z : for z in 0 to kz-1 generate
    gen_y : for y in 0 to ky-1 generate
      gen_x : for x in 0 to kx-1 generate
        constant n  : integer := x + y*nx + z*nx*ny;
      begin
        in_raster(n) <= i(z)(y)(x);
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

  gen_n : for n in 0 to n_points-1 generate
    in_scramble(scramble_lut(n)) <= in_raster(n);
  end generate gen_n;

  -- MUX Arrays
  gen_mux_bfly1 : for b in 0 to n_points/2-1 generate
    gen_mux_bfly2 : for tb in 0 to 1 generate
      signal bfly_in_reg : b25_complex := (others => (others => '0'));
    begin

      latch_bfly_in_reg : process (clock) is
        variable n : integer;
      begin
        if rising_edge(clock) then
          if (state > 0) and (state < the_log) then
            n := bfly_idx_rev(state+1, b, tb);
            case (wmul_idx(state,n)(2)) is
              when 1      => bfly_in_reg <= wmul_out(wmul_idx(state,n)(0))(wmul_idx(state,n)(1));
              when others => bfly_in_reg <= bfly_out(bfly_idx(state,n)(0))(bfly_idx(state,n)(1));
            end case;
          end if;
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
        with (wmul_idx(s,n) = (w,m,1)) select wmul_in_sel(s) <=
          bfly_out(bfly_idx(s,n)(0))(bfly_idx(s,n)(1)) when TRUE,
          (others => (others => '0')) when others;
      end generate gen_sel_wmul;

      wmul_in(w)(m) <=
        wmul_in_sel(state) when ((state > 0) and (state < the_log)) else
        (others => (others => '0'));

    end generate gen_mux_wmul2;
  end generate gen_mux_wmul1;

  gen_procs_out : for n in 0 to n_points-1 generate
    constant b  : integer := n mod (n_points/2);
    constant tb : integer := n / (n_points/2);
  begin
    with s_ready select out_buff(n) <=
      bfly_out(b)(tb) when '1',
      (others => (others => '0')) when others;
  end generate gen_procs_out;
  s_ready <=
    '1' when (state=the_log+1) else
    '0';
  o <= out_buff(0 to n_points/2) when s_ready else (others => (others => (others => '0')));

end architecture synth;
