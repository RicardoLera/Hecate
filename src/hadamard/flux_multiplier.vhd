  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flux_multiplier is
  port (
    clock, reset, run  : in  std_logic;
    a, b, a_nex, b_nex : in  t_signed;
    p                  : out t_signed;
    ready              : out std_logic
  );
end entity flux_multiplier;

architecture synth of flux_multiplier is

  signal a_sel, b_sel, sum : unsigned(signed_size-2 downto 0);
  signal shift_sum         : unsigned(signed_size-1 downto 0);
  signal a_inv, b_inv      : unsigned(signed_size-2 downto signed_size-cordic_len);
  signal p_full            : unsigned(2*signed_size-2 downto 0) := (others => '0');
  signal p_full_shifted    : unsigned(2*signed_size-2 downto 0);
  signal p_full_n          : unsigned(2*signed_size-2 downto 0);
  signal a_bit, b_bit      : std_logic;
  signal a_ready, b_ready  : std_logic;
  signal a_error, b_error  : std_logic;
  signal f_error, f_reset  : std_logic;
  signal bit_prod          : std_logic;

begin

  a_flux_inv : component flux_inverter
    port map (
      clock   => clock,
      reset_s => f_reset,
      load    => run,
      inp     => unsigned(a    (a_inv'range)),
      nex     => unsigned(a_nex(a_inv'range)),
      outp    => a_inv,
      new_bit => a_bit,
      ready   => a_ready,
      err     => a_error
    );

  b_flux_inv : component flux_inverter
    port map (
      clock   => clock,
      reset_s => f_reset,
      load    => run,
      inp     => unsigned(b    (b_inv'range)),
      nex     => unsigned(b_nex(b_inv'range)),
      outp    => b_inv,
      new_bit => b_bit,
      ready   => b_ready,
      err     => b_error
    );
  
  proc : process (clock) begin
    if rising_edge(clock) then
      if (f_reset) then
        p_full <= (others => '0');
      elsif (run and not ready) then
        p_full <= p_full_n;
      end if;
    end if;
  end process proc;

  ready   <= a_ready and b_ready;
  f_error <= a_error or b_error;
  f_reset <= f_error or reset;

  with b_bit select a_sel <= (a_inv'range => unsigned(a_inv), others => '0') when '1',
    (others => '0') when others;

  with a_bit select b_sel <= (b_inv'range => unsigned(b_inv), others => '0') when '1',
    (others => '0') when others;

  sum <= a_sel + b_sel;

  shift_sum <= resize(sum sll 1, signed_size);
  p_full_shifted <= p_full sll 2;

  bit_prod <= a_bit and b_bit;
  p_full_n <= p_full_shifted + shift_sum + bit_prod;
  
  p <= signed(resize(unsigned(p_full srl (signed_point+the_log-2*(signed_size-cordic_len))), signed_size));
  -- go downto to fixed point
  -- -2*(signed_size-cordic_len) for cordic lenght correction
  -- +the_log to divide by N (FFT)
end architecture synth;