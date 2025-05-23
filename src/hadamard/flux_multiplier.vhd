  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity flux_multiplier is
  generic (
    n_idx     : natural := 0
  );
  port (
    clock     : in    std_logic;
    reset     : in    std_logic;
    run       : in    std_logic;
    run_coefs : in    std_logic;
    a         : in    std_logic_vector(23 downto 0);
    b         : in    std_logic_vector(23 downto 0);
    a_nex     : in    std_logic_vector(23 downto 0);
    b_nex     : in    std_logic_vector(23 downto 0);
    coefs_x   : out   b25_real_array(0 to n_points/4-1);
    coefs_y   : out   b25_real_array(0 to n_points/4-1);
    p         : out   std_logic_vector(24 downto 0);
    ready     : out   std_logic
  );
end entity flux_multiplier;

architecture synth of flux_multiplier is

  constant the_log : integer := integer(ceil(log2(real(n_points))));

  signal a_flux,   b_flux : std_logic_vector(23 downto 0);
  signal a_sel            : ieee.numeric_std.unsigned(24 downto 0);
  signal b_sel            : ieee.numeric_std.unsigned(24 downto 0);
  signal sum              : ieee.numeric_std.unsigned(24 downto 0);
  signal shift_sum        : std_logic_vector(49 downto 0) := (others => '0');
  signal a_bit            : std_logic;
  signal b_bit            : std_logic;
  signal bit_prod         : std_logic;
  signal a_ready          : std_logic;
  signal b_ready          : std_logic;
  signal s_ready          : std_logic;
  signal a_error          : std_logic;
  signal b_error          : std_logic;
  signal s_error          : std_logic;
  signal s_reset          : std_logic;

  signal p_full                   : std_logic_vector(49 downto 0) := (others => '0');
  signal p_full_n, p_full_shifted : std_logic_vector(49 downto 0);

  signal kx_mux_x   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_add_x   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_reg_x   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_shift_x : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_mux_y   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_add_y   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_reg_y   : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));
  signal kx_shift_y : b25_double_array(0 to n_points/4-1) := (others => (others => '0'));

begin

  a_flux_inv : component flux_inverter
    port map (
      clock    => clock,
      reset_s  => s_reset,
      reset_as => '0',
      load     => run,
      inp      => a(23 downto 0),
      nex      => a_nex(23 downto 0),
      outp     => a_flux,
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
      inp      => b(23 downto 0),
      nex      => b_nex(23 downto 0),
      outp     => b_flux,
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

  s_ready <= a_ready and b_ready;
  ready   <= s_ready;

  s_error <= a_error or b_error;
  s_reset <= s_error or reset;

  with b_bit select a_sel <=
    '0' & ieee.numeric_std.unsigned(a_flux) when '1',
    25x"0" when others;

  with a_bit select b_sel <=
    '0' & ieee.numeric_std.unsigned(b_flux) when '1',
    25x"0" when others;

  sum <= a_sel + b_sel;

  shift_sum(49 downto 26) <= (others => '0');
  shift_sum(25 downto 1)  <= std_logic_vector(sum);
  shift_sum(0)            <= '0';

  bit_prod <= a_bit and b_bit;

  p_full_shifted(1 downto 0)  <= "00";
  p_full_shifted(49 downto 2) <= p_full(47 downto 0);

  adder : component adder_carry
    port map (
      a   => p_full_shifted,
      b   => shift_sum,
      cin => bit_prod,
      o   => p_full_n
    );

  p <= p_full(40 downto 16) srl 5; -- 25 + 16 - 1 downto 16 -- and then divided by 32 because DFT

  -- constant multipliers (kx)

  kx_gen : for w in 0 to n_points/4-1 generate
    kx_sel_loop : for s in 1 to the_log-2 generate

      kx_sel_if : if (
      ((w = 0) and (s=1)) or -- only generate w=0 once
      ((n_idx mod (2**s) = (2**(s-1))) and (w mod (2**(s-1)) = 0))
      ) generate

        kx_proc : process (clock) begin
          if rising_edge(clock) then
            if (reset or s_reset) then
              kx_reg_x(w) <= (others => '0');
              kx_reg_y(w) <= (others => '0');
              --coefs_x(w) <= (others => '0');
              --coefs_y(w) <= (others => '0');
            elsif (run_coefs) then
              kx_reg_x(w) <= kx_add_x(w);
              kx_reg_y(w) <= kx_add_y(w);
            end if;
          end if;
        end process kx_proc;

        kx_mux_x(w)(49 downto 25) <= (others => '0');
        kx_mux_y(w)(49 downto 25) <= (others => '0');

        with a_bit select kx_mux_x(w)(24 downto 0) <=
          kw_lut(w) when '1',
          25x"0" when others;
        with b_bit select kx_mux_y(w)(24 downto 0) <=
          kw_lut(w) when '1',
          25x"0" when others;
      
        kx_shift_x(w)(49 downto 1) <= kx_reg_x(w)(48 downto 0);
        kx_shift_y(w)(49 downto 1) <= kx_reg_y(w)(48 downto 0);

        kx_add_x(w) <= std_logic_vector(unsigned(kx_mux_x(w)) + unsigned(kx_shift_x(w)));
        kx_add_y(w) <= std_logic_vector(unsigned(kx_mux_y(w)) + unsigned(kx_shift_y(w)));

        coefs_x(w) <= kx_reg_x(w)(40 downto 16);
        coefs_y(w) <= kx_reg_y(w)(40 downto 16);

      --elsif (b=the_log-2) generate
        --coefs_x(w) <= (others => '0'); -- not sure if this makes a ton of hardware
        --coefs_y(w) <= (others => '0');
      end generate kx_sel_if;
    end generate kx_sel_loop;
  end generate kx_gen;

end architecture synth;
