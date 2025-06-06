  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flux_multiplier is
  port (
    clock, reset, run  : in    std_logic;
    a, b, a_nex, b_nex : in    s25;
    p                  : out   s25;
    ready              : out   std_logic
  );
end entity flux_multiplier;

architecture synth of flux_multiplier is

  signal a_pos, b_pos, a_nex_pos, b_nex_pos : unsigned(23 downto 0);

  signal a_inv, b_inv : unsigned(cordic_len-2 downto 0);
  signal a_sel        : unsigned(23 downto 0);
  signal b_sel        : unsigned(23 downto 0);
  signal sum          : unsigned(23 downto 0);
  signal shift_sum    : unsigned(48 downto 0) := (others => '0');
  signal a_bit        : std_logic;
  signal b_bit        : std_logic;
  signal bit_prod     : std_logic;
  signal a_ready      : std_logic;
  signal b_ready      : std_logic;
  signal a_error      : std_logic;
  signal b_error      : std_logic;
  signal s_error      : std_logic;
  signal s_reset      : std_logic;

  signal p_full                   : unsigned(48 downto 0) := (others => '0');
  signal p_full_n, p_full_shifted : unsigned(48 downto 0);

begin

  -- Assert positive input values
  a_pos <= unsigned(a(23 downto 0)) when not a(24) else (others => '0');
  b_pos <= unsigned(b(23 downto 0)) when not b(24) else (others => '0');
  a_nex_pos <= unsigned(a_nex(23 downto 0)) when not a_nex(24) else (others => '0');
  b_nex_pos <= unsigned(b_nex(23 downto 0)) when not b_nex(24) else (others => '0');


  a_flux_inv : component flux_inverter
    port map (
      clock    => clock,
      reset_s  => s_reset,
      reset_as => '0',
      load     => run,
      inp      => a_pos(23 downto 25-cordic_len),
      nex      => a_nex_pos(23 downto 25-cordic_len),
      outp     => a_inv,
      new_bit  => a_bit,
      ready    => a_ready,
      erro     => a_error
    );

  b_flux_inv : component flux_inverter
    port map (
      clock    => clock,
      reset_s  => s_reset,
      reset_as => '0',
      load     => run,
      inp      => b_pos(23 downto 25-cordic_len),
      nex      => b_nex_pos(23 downto 25-cordic_len),
      outp     => b_inv,
      new_bit  => b_bit,
      ready    => b_ready,
      erro     => b_error
    );

  proc : process (clock) begin
    if rising_edge(clock) then
      if (reset or s_reset) then
        p_full <= (others => '0');
      elsif (run and not ready) then
        p_full <= p_full_n;
      end if;
    end if;
  end process proc;

  ready <= a_ready and b_ready;

  s_error <= a_error or b_error;
  s_reset <= s_error or reset;

  with b_bit select a_sel <= (cordic_len-2 downto 0 => unsigned(a_inv), others => '0') when '1',
    (others => '0') when others;

  with a_bit select b_sel <= (cordic_len-2 downto 0 => unsigned(b_inv), others => '0') when '1',
    (others => '0') when others;

  sum <= a_sel + b_sel;

  shift_sum <= (24 downto 1 => sum, others => '0');

  bit_prod <= a_bit and b_bit;

  p_full_shifted <= (48 downto 2 => p_full(46 downto 0), 1 downto 0 => '0');

  adder : component adder_carry
    port map (
      a   => p_full_shifted,
      b   => shift_sum,
      cin => bit_prod,
      o   => p_full_n
    );

  p <= signed(p_full(40 - 2*(25-cordic_len) + the_log downto 16 - 2*(25-cordic_len) + the_log));
    -- 25 + 16 - 1 downto 16 -- and then divided by N because FFT

end architecture synth;