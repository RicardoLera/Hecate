library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flux_multiplier is
  generic (
    n_idx     : natural range 0 to 8 := 0
  );
  port (
    clock   : in    std_logic;
    reset   : in    std_logic;
    run     : in    std_logic;
    a       : in    std_logic_vector(24 downto 0);
    b       : in    std_logic_vector(24 downto 0);
    a_nex   : in    std_logic_vector(24 downto 0);
    b_nex   : in    std_logic_vector(24 downto 0);
    coefs_x : out   b25_real_array(0 to 7);
    coefs_y : out   b25_real_array(0 to 7);
    p       : out   std_logic_vector(24 downto 0);
    ready   : out   std_logic
  );
end entity flux_multiplier;

architecture synth of flux_multiplier is

  signal a_flux,   b_flux : std_logic_vector(23 downto 0);
  signal a_sel            : ieee.numeric_std.unsigned(24 downto 0);
  signal b_sel            : ieee.numeric_std.unsigned(24 downto 0);
  signal sum              : ieee.numeric_std.unsigned(24 downto 0);
  signal shift_sum        : std_logic_vector(49 downto 0) := (others => '0');
  signal shift_res        : std_logic_vector(49 downto 0) := (others => '0');
  signal next_res         : std_logic_vector(49 downto 0) := (others => '0');
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

  signal p_full,   a_kx           : std_logic_vector(49 downto 0) := (others => '0');
  signal p_full_n, p_full_shifted : std_logic_vector(49 downto 0);

  signal kx_mux_x   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_add_x   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_reg_x   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_shift_x : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_mux_y   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_add_y   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_reg_y   : b25_double_array(0 to 7) := (others => (others => '0'));
  signal kx_shift_y : b25_double_array(0 to 7) := (others => (others => '0'));

-- signal p_full_shifted_u, shift_sum_u : unsigned((2 * size) - 1 downto 0);
-- signal bit_prod_u : unsigned((2*size)-1 downto 0);

begin

  proc : process (clock) is
  begin

    if rising_edge(clock) then
      if (s_reset = '1') then
        p_full <= (others => '0');
      elsif (run = '1' and s_ready = '0') then
        p_full <= p_full_n;
      end if;
    end if;

  end process proc; -- proc

  s_ready <= a_ready and b_ready;
  ready   <= s_ready;

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

  s_error <= a_error or b_error;
  s_reset <= s_error or reset;

  with b_bit select a_sel <=
    '0' & ieee.numeric_std.unsigned(a_flux) when '1',
    x"0" when others;

  with a_bit select b_sel <=
    '0' & ieee.numeric_std.unsigned(b_flux) when '1',
    x"0" when others;

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

  p <= p_full(40 downto 16); -- 25 + 16 - 1 downto 16

  -- constant multipliers (kx)

  kx_x : for idx in 0 to 7 generate
  begin

    select_gen_x : if (n_idx mod 2 = 1) or ((n_idx mod 4 = 2) and (idx mod 4 = 2)) or ((n_idx = 0) and (idx = 0)) generate

      kx_mux_x(idx)(49 downto 25) <= (others => '0');
      with a_bit select kx_mux_x(idx)(24 downto 0) <=
        kw_lut(idx) when '1',
        x"0" when others;

      kx_proc_x : process (clock) is
      begin

        if rising_edge(clock) then
          if (s_reset = '1') then
            kx_reg_x(idx) <= (others => '0');
          elsif (run = '1' and s_ready = '0') then
            kx_reg_x(idx) <= kx_add_x(idx);
          end if;
        end if;

      end process kx_proc_x;

      kx_add_x(idx) <= std_logic_vector(unsigned(kx_mux_x(idx)) + unsigned(kx_shift_x(idx)));
      kx_shift_x(idx)(49 downto 1) <= kx_reg_x(idx)(48 downto 0);

      coefs_x(idx) <= kx_reg_x(idx)(41 downto 16);

    else generate
      coefs_x(idx) <= (others => '0'); -- not sure if this makes a ton of hardware
    end generate select_gen_x;

  end generate kx_x;

  kx_y : for idx in 0 to 7 generate
  begin

    select_gen_y : if (n_idx mod 2 = 1) or ((n_idx mod 4 = 2) and (idx mod 4 = 2)) or ((n_idx = 0) and (idx = 0)) generate

      kx_mux_y(idx)(49 downto 25) <= (others => '0');
      with a_bit select kx_mux_y(idx)(24 downto 0) <=
        kw_lut(idx) when '1',
        x"0" when others;

      kx_proc_y : process (clock) is
      begin

        if rising_edge(clock) then
          if (s_reset = '1') then
            kx_reg_y(idx) <= (others => '0');
          elsif (run = '1' and s_ready = '0') then
            kx_reg_y(idx) <= kx_add_y(idx);
          end if;
        end if;

      end process kx_proc_y;

      kx_add_y(idx) <= std_logic_vector(unsigned(kx_mux_y(idx)) + unsigned(kx_shift_y(idx)));
      kx_shift_y(idx)(49 downto 1) <= kx_reg_y(idx)(48 downto 0);

      coefs_y(idx) <= kx_reg_y(idx)(41 downto 16);

    else generate
      coefs_y(idx) <= (others => '0');
    end generate select_gen_y;

  end generate kx_y;

end architecture synth;
