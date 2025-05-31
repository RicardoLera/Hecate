  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity ifft is
  port (
    i                   : in  b25_complex_array(0 to n_points/2);
    o                   : out b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
    clock, reset, start : in  std_logic;
    s_ready             : out std_logic
  );
end entity ifft;

architecture synth of ifft is

  signal state : natural range 0 to the_log+1 := 0; -- state 1 is synchronous start

  signal in_raster         : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));
  signal bfly_in, bfly_out : b25_2d_complex_array(0 to n_points/2-1)(0 to 1) := (others => (others => (others => (others => '0')))); -- 0-top; 1-bottom
  signal wmul_in, wmul_out : b25_2d_complex_array(0 to n_points/2-1)(0 to n_points/4-1) := (others => (others => (others => (others => '0'))));
  signal out_buff          : b25_complex_array(0 to n_points-1) := (others => (others => (others => '0')));

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
    gen_wmul2 : for m in 0 to n_points/8-1 generate -- max needed mults for w /= 0 and n_points/4
      gen_wmul3 : if (w /= n_points/4) generate

        wmul_sel_if : if (fft_nmul_lut(w)(m)) generate 
            wmul : component b25_wmul
              generic map (n_points - w) -- FFT/IFFT inversion
              port map (
                i => wmul_in(w)(m),
                o => wmul_out(w)(m)
              );
        end generate wmul_sel_if;

      end generate gen_wmul3;
    end generate gen_wmul2;
  end generate gen_wmul;
  
  gen_wmul4 : for m in 0 to n_points/4-1 generate -- FFT/IFFT inversion applied here too
    wmul_out(n_points/4)(m) <= (                                                     -- (a + bi)*-i = 
      wmul_in(n_points/4)(m)(1),                                                     -- +b
      ((not wmul_in(n_points/4)(m)(0)(24)) & wmul_in(n_points/4)(m)(0)(23 downto 0)) -- -ai
    );
  end generate gen_wmul4;

  wmul_out(0) <= wmul_in(0);

  -- State machine
  state_machine : process (clock, reset) begin
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
  gen_n : for n in 0 to n_points-1 generate
    gen_n_if : if (n <= n_points/2) generate
      in_raster(n) <= i(n);
    else generate
      in_raster(n)(0) <= i(n_points-n)(0);
      in_raster(n)(1) <= (not i(n_points-n)(1)(24) & i(n_points-n)(1)(23 downto 0));
    end generate gen_n_if;
  end generate gen_n;

  -- MUX Arrays
  gen_mux_bfly1 : for b in 0 to n_points/2-1 generate
    gen_mux_bfly2 : for tb in 0 to 1 generate
      signal bfly_in_reg : b25_complex := (others => (others => '0'));
    begin

      latch_bfly_in_reg : process (clock) is
        variable n : natural;
      begin
        if rising_edge(clock) then
          if (state > 0) and (state < the_log) then
            n := bfly_lut_rev(state+1)(b)(tb);
            case (wmul_lut(state)(n)(2)) is
              when 1      => bfly_in_reg <= wmul_out(wmul_lut(state)(n)(0))(wmul_lut(state)(n)(1));
              when others => bfly_in_reg <= bfly_out(bfly_lut(state)(n)(0))(bfly_lut(state)(n)(1));
            end case;
          end if;
        end if;
      end process latch_bfly_in_reg;

      with state select bfly_in(b)(tb) <=
        (others => (others => '0')) when 0,
        in_raster(bfly_lut_rev(1)(b)(tb)) when 1,
        bfly_in_reg when others;

    end generate gen_mux_bfly2;
  end generate gen_mux_bfly1;

  gen_mux_wmul1 : for w in 0 to n_points/2-1 generate
    gen_mux_wmul2 : for m in 0 to n_points/4-1 generate
      signal wmul_in_sel : b25_complex_array(1 to the_log-1);
    begin

      gen_sel_wmul : for s in 1 to the_log-1 generate
        constant n : natural := wmul_lut_rev(s)(w)(m);
      begin
        with (wmul_lut(s)(n) = (w,m,1)) select wmul_in_sel(s) <=
          bfly_out(bfly_lut(s)(n)(0))(bfly_lut(s)(n)(1)) when TRUE,
          (others => (others => '0')) when others;
      end generate gen_sel_wmul;

      wmul_in(w)(m) <=
        wmul_in_sel(state) when ((state > 0) and (state < the_log)) else
        (others => (others => '0'));

    end generate gen_mux_wmul2;
  end generate gen_mux_wmul1;

  gen_procs_out : for n in 0 to n_points-1 generate
    constant b  : natural := n mod (n_points/2);
    constant tb : natural := n / (n_points/2);
  begin
    with s_ready select out_buff(n) <=
      bfly_out(b)(tb) when '1',
      (others => (others => '0')) when others;
  end generate gen_procs_out;
  s_ready <=
    '1' when (state=the_log+1) else
    '0';

  --Output Layer (unrasterize and unscramble)
  gen_z : for z in 0 to nz-1 generate
    gen_y : for y in 0 to ny-1 generate
      gen_x : for x in 0 to nx-1 generate
        constant idx : natural := x + y*nx + z*nx*ny;
      begin
        o(z)(y)(x) <= out_buff(scramble_lut(idx))(0) when s_ready = '1' else (others => '0');
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

end architecture synth;
