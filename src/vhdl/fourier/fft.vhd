  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Note: this FFT returns the complex conjugate compared to cor.py. It's a matter of twiddle factor selection (counterclockwise vs clockwise) and it cancels out in the IFFT, but it's worth noting
entity fft is
  port (
    i                   : in  t_signed_complex_array(0 to n_points-1);
    o                   : out t_signed_complex_array(0 to n_points-1);
    clock, reset, start : in  std_logic;
    clockwise           : in  std_logic;
    s_ready             : out std_logic
  );
end entity fft;

architecture synth of fft is

  signal layer  : natural range 0 to the_log := 0;
  signal switch : std_logic                    := '1'; -- '0' -> wmul; '1' -> bfly

  signal in_scramble       : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0')));
  signal bfly_in, bfly_out : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0'))); -- even-top; odd-bottom
  signal wmul_in, wmul_out : t_signed_complex_array(0 to n_points-1) := (others => (others => (others => '0')));
  signal wmul_w            : t_natural_array       (0 to n_points-1) := (others => 0); 

begin

  -- Input/Output layer (scramble)
  gen_scramble : for n in 0 to n_points-1 generate
    in_scramble(scramble_lut(n)) <= i(n);
    o(n) <= bfly_out(fft_net_lut(n)(the_log));
  end generate gen_scramble;

  -- Generate butterflies and complex constant multiplers
  gen_bfly_wmul : for n in 0 to n_points/2-1 generate
    bfly : component butterfly
      port map (
        i_top => bfly_in(2*n),
        i_bot => bfly_in(2*n+1),
        o_top => bfly_out(2*n),
        o_bot => bfly_out(2*n+1)
      );
    w_mul : component wmul
      port map (
        i => wmul_in(2*n+1),
        w => wmul_w(2*n+1),
        s => clockwise,
        o => wmul_out(2*n+1)
      );
    wmul_out(2*n) <= wmul_in(2*n);
    -- max needed mults is n_points/2 -(w^(N/4)=i mul) -(w^0=1 mul)
  end generate gen_bfly_wmul;

  -- Layer-switch state machine
  fsm : process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        layer <= 0; switch <= '1'; s_ready <= '0';
      elsif (start and not s_ready) then

        if (layer < the_log) then
          if switch then layer <= layer + 1; end if; -- signal updates are not sequential
          switch <= not switch;
        end if;

        if layer = the_log then
          s_ready <= '1';
        end if;

      end if;
    end if;
  end process;

  -- Signal assignments 
  fnet : for n in 0 to n_points-1 generate
    fnet_proc : process(clock) begin
      if rising_edge(clock) then
        if ((start='1') and (layer /= the_log)) then
          case layer is
            when 0 =>
              bfly_in(n) <= in_scramble(n);
            when others =>
              if switch then
                bfly_in(n) <= wmul_out(n);
              else
                -- report "l = " & integer'image(layer) &  "   n = " & integer'image(n) & "   => net = " & integer'image(fft_net_lut(n)(layer));
                wmul_in(n) <= bfly_out(fft_net_lut(n)(layer));
                wmul_w(n)  <= fft_w_lut(n)(layer);
              end if;
          end case;
        end if;
      end if;
    end process fnet_proc;
  end generate fnet;

end architecture synth;
