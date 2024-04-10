library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  generic (
    logn  : natural RANGE 1 to 3 := 3;
    n_idx : natural range 0 to 7 := 0
  );
  port (
    clock     : in    std_logic;
    reset     : in    std_logic;
    start     : in    std_logic;
    x_i       : in    std_logic_vector(24 downto 0);
    y_i       : in    std_logic_vector(24 downto 0);
    x_k       : in    std_logic_vector(24 downto 0);
    y_k       : in    std_logic_vector(24 downto 0); -- s_iiii'iiii.ffff'ffff'ffff'ffff
    lut       : in    std_logic_vector(((logn + 1) * 25) - 1 downto 0);
    p_coefs_x : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
    p_coefs_y : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
    ready     : buffer std_logic

  -- debugging ports
  -- db_ch1, db_ch2 : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
  -- db_c1, db_c2, db_c3, db_c4 : OUT STD_LOGIC_VECTOR(24 DOWNTO 0);
  -- db_in_bit : IN STD_LOGIC;
  -- db_in_coor : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
  -- db_in_ang : IN STD_LOGIC_VECTOR(24 DOWNTO 0)
  );
end entity hadamard;

architecture arch of hadamard is

  component flux_multiplier is
    generic (
      size      : natural              := 25;
      frac_size : natural              := 16;
      logn      : natural RANGE 1 to 3 := 3;
      n_idx     : natural range 0 to 7 := 0
    );
    port (
      clock   : in    std_logic;
      reset   : in    std_logic;
      run     : in    std_logic;
      a       : in    std_logic_vector(size - 1 downto 0);
      b       : in    std_logic_vector(size - 1 downto 0);
      a_nex   : in    std_logic_vector(size - 1 downto 0);
      b_nex   : in    std_logic_vector(size - 1 downto 0);
      lut     : in    std_logic_vector(((logN + 1) * size) - 1 downto 0);
      coefs_x : out   std_logic_vector(((logN + 1) * size) - 1 downto 0);
      coefs_y : out   std_logic_vector(((logN + 1) * size) - 1 downto 0);
      p       : out   std_logic_vector(size - 1 downto 0);
      ready   : out   std_logic
    );
  end component;

  component hadamard_uc is
    port (
      clock           : in    std_logic;
      start           : in    std_logic;
      reset           : in    std_logic;
      mul_ready       : in    std_logic;
      j_end           : in    std_logic;
      load_change     : out   std_logic;
      cordic_feedback : out   std_logic;
      flux_to_cordic  : out   std_logic;
      freeze_terms    : out   std_logic;
      mul_xy          : out   std_logic;
      cordic_rotation : out   std_logic;
      ready           : buffer std_logic
    );
  end component;

  component cordic is
    generic (
      j_len      : natural := 5;
      coords_len : natural := 25
    );
    port (
      sigma_in  : in    std_logic;
      rotation  : in    std_logic;
      j         : in    std_logic_vector(j_len - 1 downto 0);
      x_in      : in    std_logic_vector(coords_len - 1 downto 0);
      y_in      : in    std_logic_vector(coords_len - 1 downto 0);
      z_in      : in    std_logic_vector(coords_len - 1 downto 0);
      x_out     : out   std_logic_vector(coords_len - 1 downto 0);
      y_out     : out   std_logic_vector(coords_len - 1 downto 0);
      z_out     : out   std_logic_vector(coords_len - 1 downto 0);
      sigma_out : out   std_logic
    );
  end component;

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  -- Control unit signals
  signal mul_ready,  j_end : std_logic;
  signal load_change       : std_logic;
  signal cordic_feedback   : std_logic;
  signal flux_to_cordic    : std_logic;
  signal freeze_terms      : std_logic;
  signal mul_xy            : std_logic;
  signal cordic_rotation   : std_logic;

  -- Change and signal treatment signals
  signal increment_change : std_logic;
  signal in_change_img    : std_logic_vector(1 downto 0);
  signal in_change_ker    : std_logic_vector(1 downto 0);
  signal in_change_sum    : std_logic_vector(1 downto 0);
  signal inc_change       : std_logic_vector(1 downto 0);
  signal next_change      : std_logic_vector(1 downto 0);
  signal cur_change       : std_logic_vector(1 downto 0) := (OTHERS => '0');
  signal x_i_abs          : std_logic_vector(24 downto 0);
  signal y_i_abs          : std_logic_vector(24 downto 0);
  signal x_k_abs          : std_logic_vector(24 downto 0);
  signal y_k_abs          : std_logic_vector(24 downto 0);
  signal x_i_n            : std_logic_vector(24 downto 0);
  signal y_i_n            : std_logic_vector(24 downto 0);
  signal x_k_n            : std_logic_vector(24 downto 0);
  signal y_k_n            : std_logic_vector(24 downto 0);

  -- Secondary CORDIC signals
  signal sc_x_cur,   sc_y_cur : std_logic_vector(24 downto 0) := (OTHERS => '0');
  signal sc_z_cur             : std_logic_vector(24 downto 0) := (OTHERS => '0');
  signal sc_sig_cur           : std_logic                     := '0';

  signal sc_x_nex               : std_logic_vector(24 downto 0);
  signal sc_y_nex               : std_logic_vector(24 downto 0);
  signal sc_x_cor               : std_logic_vector(24 downto 0);
  signal sc_y_cor               : std_logic_vector(24 downto 0);
  signal sc_z_nex,   sc_z_cor   : std_logic_vector(24 downto 0);
  signal sc_sig_nex, sc_sig_cor : std_logic;

  -- J control

  signal j : std_logic_vector(4 downto 0) := (OTHERS => '0');

  -- Primary CORDIC

  signal pc_x_cur,   pc_y_cur : std_logic_vector(24 downto 0) := (OTHERS => '0');
  signal pc_z_cur             : std_logic_vector(24 downto 0) := (OTHERS => '0');
  signal pc_sig_cur           : std_logic                     := '0';

  signal pc_x_nex   : std_logic_vector(24 downto 0);
  signal pc_y_nex   : std_logic_vector(24 downto 0);
  signal pc_x_cor   : std_logic_vector(24 downto 0);
  signal pc_y_cor   : std_logic_vector(24 downto 0);
  signal pc_x_sel   : std_logic_vector(24 downto 0);
  signal pc_y_sel   : std_logic_vector(24 downto 0);
  signal pc_z_nex   : std_logic_vector(24 downto 0);
  signal pc_z_cor   : std_logic_vector(24 downto 0);
  signal pc_z_sel   : std_logic_vector(24 downto 0);
  signal pc_sig_nex : std_logic;
  signal pc_sig_cor : std_logic;
  signal pc_sig_sel : std_logic;

  constant pi            : std_logic_vector(23 downto 0) := "000000110010010000111111"; -- 011.0010010000111111
  constant two_pi        : std_logic_vector(23 downto 0) := "000001100100100001111110"; -- 110.0100100001111110
  constant half_pi       : std_logic_vector(23 downto 0) := "000000011001001000011111"; -- 001.1001001000011111
  constant three_half_pi : std_logic_vector(23 downto 0) := "000001001011011001011101"; -- 100.1011011001011101

  -- Multiplier

  signal prod_z          : std_logic_vector(24 downto 0);
  signal prod_z_norm     : std_logic_vector(24 downto 0);
  signal prod_mod        : std_logic_vector(24 downto 0);
  signal z_pi            : std_logic_vector(24 downto 0);
  signal mul_a           : std_logic_vector(24 downto 0);
  signal mul_a_nex       : std_logic_vector(24 downto 0);
  signal mul_b           : std_logic_vector(24 downto 0);
  signal mul_b_nex       : std_logic_vector(24 downto 0);
  signal mul_b_nex_sel   : std_logic_vector(24 downto 0);
  signal mul_coefs_x     : std_logic_vector(((logn + 1) * 25) - 1 downto 0);
  signal mul_coefs_y     : std_logic_vector(((logn + 1) * 25) - 1 downto 0);
  signal neg_mul_coefs_x : std_logic_vector(((logn + 1) * 25) - 1 downto 0);
  signal neg_mul_coefs_y : std_logic_vector(((logn + 1) * 25) - 1 downto 0);

  -- Output
  signal p_coefs_nex_x : std_logic_vector(((logn + 1) * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_nex_y : std_logic_vector(((logn + 1) * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_x_s   : std_logic_vector(((logn + 1) * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_y_s   : std_logic_vector(((logn + 1) * 25) - 1 downto 0) := (OTHERS => '0');

begin

  -- Control unit

  uc : component hadamard_uc
    port map (
      clock           => clock,
      start           => start,
      reset           => reset,
      mul_ready       => mul_ready,
      j_end           => j_end,
      load_change     => load_change,
      cordic_feedback => cordic_feedback,
      flux_to_cordic  => flux_to_cordic,
      freeze_terms    => freeze_terms,
      mul_xy          => mul_xy,
      cordic_rotation => cordic_rotation,
      ready           => ready
    );

  -- Initial sign treatment and change generation

  -- Image

  in_change_img(0) <= x_i(x_i'length - 1) xor y_i(y_i'length - 1);
  in_change_img(1) <= y_i(y_i'length - 1);

  with x_i(x_i'length - 1) select x_i_abs <=
    std_logic_vector(unsigned(NOT x_i) + to_unsigned(1, x_i'length)) when '1',
    x_i when OTHERS;

  with y_i(y_i'length - 1) select y_i_abs <=
    std_logic_vector(unsigned(NOT y_i) + to_unsigned(1, y_i'length)) when '1',
    y_i when OTHERS;

  with (x_i(x_i'length - 1) xor y_i(y_i'length - 1)) select x_i_n <=
    y_i_abs when '1',
    x_i_abs when OTHERS;

  with (x_i(x_i'length - 1) xor y_i(y_i'length - 1)) select y_i_n <=
    x_i_abs when '1',
    y_i_abs when OTHERS;

  -- Kernel

  in_change_ker(0) <= x_k(x_k'length - 1) xor y_k(y_k'length - 1);
  in_change_ker(1) <= y_k(y_k'length - 1);

  with x_k(x_k'length - 1) select x_k_abs <=
    std_logic_vector(unsigned(NOT x_k) + to_unsigned(1, x_k'length)) when '1',
    x_k when OTHERS;

  with y_k(y_i'length - 1) select y_k_abs <=
    std_logic_vector(unsigned(NOT y_k) + to_unsigned(1, y_k'length)) when '1',
    y_k when OTHERS;

  with (x_k(x_k'length - 1) xor y_k(y_k'length - 1)) select x_k_n <=
    y_k_abs when '1',
    x_k_abs when OTHERS;

  with (x_k(x_k'length - 1) xor y_k(y_k'length - 1)) select y_k_n <=
    x_k_abs when '1',
    y_k_abs when OTHERS;

  -- Change processing circuit

  in_change_sum <= std_logic_vector(unsigned(in_change_img) + unsigned(in_change_ker));

  with flux_to_cordic select next_change <=
    inc_change when '1',
    in_change_sum when OTHERS;

  with increment_change select inc_change <=
    std_logic_vector(unsigned(cur_change) + to_unsigned(1, 2)) when '1',
    cur_change when OTHERS;

  change_process : process (clock) is
  begin

    if rising_edge(clock) then
      if (reset = '1') then
        cur_change <= (OTHERS => '0');
      elsif (load_change = '1') then
        cur_change <= next_change;
      end if;
    end if;

  end process change_process; -- change_process

  -- Secondary CORDIC

  sec_cordic : component cordic
    generic map (
      j_len => 5, coords_len=> 25
    )
    port map (
      sigma_in  => sc_sig_cur,
      rotation  => '0',
      j         => j,
      x_in      => sc_x_cur,
      y_in      => sc_y_cur,
      z_in      => sc_z_cur,
      x_out     => sc_x_cor,
      y_out     => sc_y_cor,
      z_out     => sc_z_cor,
      sigma_out => sc_sig_cor
    );

  sc_cor_pro : process (clock) is
  begin

    if rising_edge(clock) then
      if (reset = '1') then
        sc_x_cur   <= (OTHERS => '0');
        sc_y_cur   <= (OTHERS => '0');
        sc_z_cur   <= (OTHERS => '0');
        sc_sig_cur <= '0';
      elsif (freeze_terms = '0') then
        sc_x_cur   <= sc_x_nex;
        sc_y_cur   <= sc_y_nex;
        sc_z_cur   <= sc_z_nex;
        sc_sig_cur <= sc_sig_nex;
      end if;
    end if;

  end process sc_cor_pro; -- sc_cor_pro

  with cordic_feedback select sc_x_nex <=
    sc_x_cor when '1',
    x_i_n when OTHERS;
  with cordic_feedback select sc_y_nex <=
    sc_y_cor when '1',
    y_i_n when OTHERS;
  with cordic_feedback select sc_z_nex <=
    sc_z_cor when '1',
    (OTHERS => '0') when OTHERS;
  -- WITH cordic_feedback SELECT
  --   sc_sig_nex <= sc_sig_cor WHEN '1',
  --   '1' WHEN '0';
  sc_sig_nex <= (NOT cordic_feedback) or sc_sig_cor;

  -- J control signals

  j_control_pro : process (clock) is
  begin

    if rising_edge(clock) then
      if (cordic_feedback = '0') then
        j <= (OTHERS => '0');
      else
        j <= std_logic_vector(unsigned(j) + to_unsigned(1, 5));
      end if;
    end if;

  end process j_control_pro; -- j_control_pro

  j_end <= j(0) and j(1) and j(2) and j(3) and j(4);

  -- Primary Cordic
  pri_cordic : component cordic
    generic map (
      j_len => 5, coords_len=> 25
    )
    port map (
      sigma_in  => pc_sig_cur,
      rotation  => cordic_rotation,
      j         => j,
      x_in      => pc_x_cur,
      y_in      => pc_y_cur,
      z_in      => pc_z_cur,
      x_out     => pc_x_cor,
      y_out     => pc_y_cor,
      z_out     => pc_z_cor,
      sigma_out => pc_sig_cor
    );

  pc_cor_pro : process (clock) is
  begin

    if rising_edge(clock) then
      if (reset = '1') then
        pc_x_cur   <= (OTHERS => '0');
        pc_y_cur   <= (OTHERS => '0');
        pc_z_cur   <= (OTHERS => '0');
        pc_sig_cur <= '0';
      elsif (freeze_terms = '0') then
        pc_x_cur   <= pc_x_nex;
        pc_y_cur   <= pc_y_nex;
        pc_z_cur   <= pc_z_nex;
        pc_sig_cur <= pc_sig_nex;
      end if;
    end if;

  end process pc_cor_pro; -- sc_cor_pro

  with cordic_feedback select pc_x_sel <=
    pc_x_cor when '1',
    x_k_n when OTHERS;
  with cordic_feedback select pc_y_sel <=
    pc_y_cor when '1',
    y_k_n when OTHERS;
  with cordic_feedback select pc_z_sel <=
    pc_z_cor when '1',
    (OTHERS => '0') when OTHERS;
  -- WITH cordic_feedback SELECT
  --   sc_sig_nex <= sc_sig_cor WHEN '1',
  --   NOT cordic_rotation WHEN '0';
  pc_sig_sel <= (cordic_feedback and pc_sig_cor) or
		((NOT cordic_feedback) and (NOT cordic_rotation));

  with flux_to_cordic select pc_x_nex <=
    pc_x_sel when '0',
    prod_mod when OTHERS;
  with flux_to_cordic select pc_y_nex <=
    pc_y_sel when '0',
    (OTHERS => '0') when OTHERS;
  with flux_to_cordic select pc_z_nex <=
    pc_z_sel when '0',
    prod_z_norm when OTHERS;
  pc_sig_nex <= pc_sig_sel; -- for consistency

  -- Multiplier

  z_addition : component b25_add
    port map (
      a   => pc_z_cur,
      b   => sc_z_cur,
      res => prod_z
    );

  z_correction : component b25_add
    port map (
      a   => not z_pi(24) & prod_z(23 downto 0),
      b   => z_pi,
      res => prod_z_norm
    );

  z_pi <= (24 => '1', others => '0') when prod_z(23 downto 0) <= half_pi else
          '0' & pi when prod_z(23 downto 0) <= pi else
          '1' & pi when prod_z(23 downto 0) <= three_half_pi else
          '0' & two_pi;

  -- correction_sign <= not z_pi(24);

  -- store sign change for later

  increment_change <= prod_z(24);

  -- OBS (from prev): check if run can be left at high
  flux_mul : component flux_multiplier
    generic map (
      size => 25, frac_size=> 16, logn=> 3, n_idx=> N_idx
    )
    port map (
      clock   => clock,
      reset   => reset,
      run     => start,
      a       => mul_a,
      b       => mul_b,
      a_nex   => mul_a_nex,
      b_nex   => mul_b_nex,
      lut     => lut,
      coefs_x => mul_coefs_x,
      coefs_y => mul_coefs_y,
      p       => prod_mod,
      ready   => mul_ready
    );

  mul_a <= pc_x_cur;
  with freeze_terms select mul_a_nex <=
    mul_a when '1',
    pc_x_cor when OTHERS;
  with mul_xy select mul_b <=
    pc_y_cur when '1',
    sc_x_cur when OTHERS;
  with freeze_terms select mul_b_nex <=
    mul_b when '1',
    mul_b_nex_sel when OTHERS;
  with mul_xy select mul_b_nex_sel <=
    pc_y_nex when '1',
    sc_x_nex when OTHERS;

  -- Change processing at output

  gen_mul_negs : for i IN 0 to logn generate
    neg_mul_coefs_x(25 * (i + 1) - 1 DOWNTO 25 * i) <= std_logic_vector(unsigned(NOT mul_coefs_x(25 * (i + 1) - 1 downto 25 * i)) + to_unsigned(1, 25));
    neg_mul_coefs_y(25 * (i + 1) - 1 DOWNTO 25 * i) <= std_logic_vector(unsigned(NOT mul_coefs_y(25 * (i + 1) - 1 downto 25 * i)) + to_unsigned(1, 25));
  end generate gen_mul_negs;

  with cur_change select p_coefs_nex_x <=
    mul_coefs_x when "00",
    mul_coefs_y when "01",
    neg_mul_coefs_x when "10",
    neg_mul_coefs_y when OTHERS;

  with cur_change select p_coefs_nex_y <=
    mul_coefs_y when "00",
    neg_mul_coefs_x when "01",
    neg_mul_coefs_y when "10",
    mul_coefs_x when OTHERS;

  outp_reg : process (clock) is
  begin

    if rising_edge(clock) then
      if (ready = '0') then
        p_coefs_x_s <= p_coefs_nex_x;
        p_coefs_y_s <= p_coefs_nex_y;
      end if;
    end if;

  end process outp_reg; -- outp_reg

  p_coefs_x <= p_coefs_x_s;
  p_coefs_y <= p_coefs_y_s;

end architecture arch;
