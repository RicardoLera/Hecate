library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
-- use IEEE.std_logic_arith.all;

entity flux_multiplier is
  generic (
    size      : natural              := 25;
    frac_size : natural              := 16;
    logn      : natural RANGE 1 to 3 := 3;
    n_idx     : natural range 0 to 8 := 0
  );
  port (
    clock   : in    std_logic;
    reset   : in    std_logic;
    run     : in    std_logic;
    a       : in    std_logic_vector(size - 1 downto 0);
    b       : in    std_logic_vector(size - 1 downto 0);
    a_nex   : in    std_logic_vector(size - 1 downto 0);
    b_nex   : in    std_logic_vector(size - 1 downto 0);
    lut     : in    std_logic_vector(((logn + 1) * size) - 1 downto 0);
    coefs_x : out   std_logic_vector(((logn + 1) * size) - 1 downto 0);
    coefs_y : out   std_logic_vector(((logn + 1) * size) - 1 downto 0);
    p       : out   std_logic_vector(size - 1 downto 0);
    ready   : out   std_logic
  );
end entity flux_multiplier;

architecture synth of flux_multiplier is

  component flux_inverter is
    generic (
      size : natural := 25
    );
    port (
      clock    : in    std_logic;
      reset_s  : in    std_logic;
      reset_as : in    std_logic;
      load     : in    std_logic;
      inp      : in    std_logic_vector(size - 2 downto 0);
      nex      : in    std_logic_vector(size - 2 downto 0);
      outp     : out   std_logic_vector(size - 2 downto 0);
      new_bit  : out   std_logic;
      ready    : out   std_logic;
      erro     : out   std_logic
    );
  end component;

  component adder_carry is
    generic (
      size : natural := 32
    );
    port (
      a   : in    std_logic_vector(size - 1 downto 0);
      b   : in    std_logic_vector(size - 1 downto 0);
      cin : in    std_logic;
      o   : out   std_logic_vector(size - 1 downto 0)
    );
  end component;

  signal a_flux,   b_flux : std_logic_vector(size - 2 downto 0);
  signal a_sel            : ieee.numeric_std.unsigned(size - 1 downto 0);
  signal b_sel            : ieee.numeric_std.unsigned(size - 1 downto 0);
  signal sum              : ieee.numeric_std.unsigned(size - 1 downto 0);
  signal shift_sum        : std_logic_vector((2 * size) - 1 downto 0) := (others => '0');
  signal shift_res        : std_logic_vector((2 * size) - 1 downto 0) := (others => '0');
  signal next_res         : std_logic_vector((2 * size) - 1 downto 0) := (others => '0');
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

  signal p_full,   a_kx           : std_logic_vector((2 * size) - 1 downto 0) := (others => '0');
  signal p_full_n, p_full_shifted : std_logic_vector((2 * size) - 1 downto 0);

  signal kx_mux_x   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_add_x   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_reg_x   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_shift_x : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_mux_y   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_add_y   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_reg_y   : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');
  signal kx_shift_y : ieee.numeric_std.unsigned((2 * (logn + 1) * size) - 1 downto 0) := (others => '0');

-- SIGNAL p_full_shifted_u, shift_sum_u : unsigned((2 * size) - 1 downto 0);
-- SIGNAL bit_prod_u : unsigned((2*size)-1 downto 0);

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
    generic map (
      size => size
    )
    port map (
      clock    => clock,
      reset_s  => s_reset,
      reset_as => '0',
      load     => run,
      inp      => a(size - 2 downto 0),
      nex      => a_nex(size - 2 downto 0),
      outp     => a_flux,
      new_bit  => a_bit,
      ready    => a_ready,
      erro     => a_error
    );

  b_flux_inv : component flux_inverter
    generic map (
      size => size
    )
    port map (
      clock    => clock,
      reset_s  => s_reset,
      reset_as => '0',
      load     => run,
      inp      => b(size - 2 downto 0),
      nex      => b_nex(size - 2 downto 0),
      outp     => b_flux,
      new_bit  => b_bit,
      ready    => b_ready,
      erro     => b_error
    );

  s_error <= a_error or b_error;
  s_reset <= s_error or reset;

  with b_bit select a_sel <=
    '0' & ieee.numeric_std.unsigned(a_flux) when '1',
    to_unsigned(0, size) when others;

  with a_bit select b_sel <=
    '0' & ieee.numeric_std.unsigned(b_flux) when '1',
    to_unsigned(0, size) when others;

  sum <= a_sel + b_sel;

  shift_sum(0)                              <= '0';
  shift_sum(size downto 1)                  <= std_logic_vector(sum);
  shift_sum((2 * size) - 1 downto size + 1) <= (others => '0');

  bit_prod <= a_bit and b_bit;

  p_full_shifted(1 downto 0)                         <= "00";
  p_full_shifted(p_full_shifted'length - 1 downto 2) <= p_full(p_full_shifted'length - 3 downto 0);

  -- p_full_n <= p_full_shifted + shift_sum + ("" & bit_prod);
  -- p_full_shifted_u <= ;
  -- shift_sum_u <= ;
  --    bit_prod_u <= to_unsigned(1, 2 * size) WHEN bit_prod = '1' ELSE
  --     to_unsigned(0, 2 * size);

  adder : component adder_carry
    generic map (
      size => 2 * size
    )
    port map (
      a   => p_full_shifted,
      b   => shift_sum,
      cin => bit_prod,
      o   => p_full_n
    );

  -- p_full_n <= std_logic_vector(unsigned(p_full_shifted) + unsigned(shift_sum) + bit_prod_u);

  -- p_full_n <= STD_LOGIC_VECTOR(unsigned(p_full_shifted) + unsigned(shift_sum) + bit_prod_u);

  p <= p_full(size + frac_size - 1 downto frac_size);

  -- Constant multipliers (KX)

  kx_x : for idx in 0 to logn generate
  begin

    select_gen_x : if (n_idx mod 2 = 1) or ((n_idx mod 4 = 2) and (idx mod 4 = 2)) or ((n_idx = 0) and (idx = 0)) generate       -- Make generic later

      kx_mux_x(2 * (idx + 1) * size - 1 downto 2 * idx * size + size) <= (others => '0');
      with a_bit select kx_mux_x(2 * (idx + 1) * size - size - 1 downto 2 * idx * size) <=
        unsigned(lut((idx + 1) * size - 1 downto idx * size)) when '1',
        to_unsigned(0, size) when others;

      kx_proc_x : process (clock) is
      begin

        if rising_edge(clock) then
          if (s_reset = '1') then
            kx_reg_x(2 * (idx + 1) * size - 1 downto 2 * idx * size) <= (others => '0');
          elsif (run = '1' and s_ready = '0') then
            kx_reg_x(2 * (idx + 1) * size - 1 downto 2 * idx * size) <= kx_add_x(2 * (idx + 1) * size - 1 downto 2 * idx * size);
          end if;
        end if;

      end process kx_proc_x;

      kx_add_x(2 * (idx + 1) * size - 1 downto 2 * idx * size)       <= kx_mux_x(2 * (idx + 1) * size - 1 downto 2 * idx * size) +
                                                                        kx_shift_x(2 * (idx + 1) * size - 1 downto 2 * idx * size);
      kx_shift_x(2 * (idx + 1) * size - 1 downto 2 * idx * size + 1) <= kx_reg_x(2 * (idx + 1) * size - 2 downto 2 * idx * size);

      coefs_x((idx + 1) * size - 1 downto idx * size) <= std_logic_vector(kx_reg_x(2 * idx * size + frac_size + size - 1 downto 2 * idx * size + frac_size));
    -- coefs_x((idx+1)*size - 1 downto idx*size) <= std_logic_vector(kx_reg_x((idx+1)*size + frac_size - 1 downto idx*size + frac_size));

    else generate
      coefs_x((idx + 1) * size - 1 downto idx * size) <= (others => '0'); -- Not sure if this makes a ton of hardware
    end generate select_gen_x;

  end generate kx_x;

  kx_y : for idx in 0 to logn generate
  begin

    select_gen_y : if (n_idx mod 2 = 1) or ((n_idx mod 4 = 2) and (idx mod 4 = 2)) or ((n_idx = 0) and (idx = 0)) generate

      kx_mux_y(2 * (idx + 1) * size - 1 downto 2 * idx * size + size) <= (others => '0');
      with b_bit select kx_mux_y(2 * (idx + 1) * size - size - 1 downto 2 * idx * size) <=
        unsigned(lut((idx + 1) * size - 1 downto idx * size)) when '1',
        to_unsigned(0, size) when others;

      kx_proc_y : process (clock) is
      begin

        if rising_edge(clock) then
          if (s_reset = '1') then
            kx_reg_y(2 * (idx + 1) * size - 1 downto 2 * idx * size) <= (others => '0');
          elsif (run = '1' and s_ready = '0') then
            kx_reg_y(2 * (idx + 1) * size - 1 downto 2 * idx * size) <= kx_add_y(2 * (idx + 1) * size - 1 downto 2 * idx * size);
          end if;
        end if;

      end process kx_proc_y;

      kx_add_y(2 * (idx + 1) * size - 1 downto 2 * idx * size)       <= kx_mux_y(2 * (idx + 1) * size - 1 downto 2 * idx * size) +
                                                                        kx_shift_y(2 * (idx + 1) * size - 1 downto 2 * idx * size);
      kx_shift_y(2 * (idx + 1) * size - 1 downto 2 * idx * size + 1) <= kx_reg_y(2 * (idx + 1) * size - 2 downto 2 * idx * size);

      coefs_y((idx + 1) * size - 1 downto idx * size) <= std_logic_vector(kx_reg_y(2 * idx * size + frac_size + size - 1 downto 2 * idx * size + frac_size));
    -- coefs_y((idx+1)*size - 1 downto idx*size) <= std_logic_vector(kx_reg_y((idx+1)*size + frac_size - 1 downto idx*size + frac_size));

    else generate
      coefs_y((idx + 1) * size - 1 downto idx * size) <= (others => '0');
    end generate select_gen_y;

  end generate kx_y;

end architecture synth;
