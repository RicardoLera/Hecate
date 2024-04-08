library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  generic (
    lut_size : natural RANGE 1 to 4 := 1
  );
  port (
    clock     : in    std_logic;
    reset     : in    std_logic;
    start     : in    std_logic;
    x_i       : in    std_logic_vector(24 downto 0);
    y_i       : in    std_logic_vector(24 downto 0);
    x_k       : in    std_logic_vector(24 downto 0);
    y_k       : in    std_logic_vector(24 downto 0); -- s_iiii'iiii.ffff'ffff'ffff'ffff
    lut       : in    std_logic_vector((lut_size * 25) - 1 downto 0);
    p_coefs_x : out   std_logic_vector((lut_size * 25) - 1 downto 0);
    p_coefs_y : out   std_logic_vector((lut_size * 25) - 1 downto 0);
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
      size      : natural := 8;
      frac_size : natural := 4;
      lut_size  : natural RANGE 1 to 4 := 1
    );
    port (
      clock   : in    std_logic;
      reset   : in    std_logic;
      run     : in    std_logic;
      a       : in    std_logic_vector(size - 1 downto 0);
      b       : in    std_logic_vector(size - 1 downto 0);
      a_nex   : in    std_logic_vector(size - 1 downto 0);
      b_nex   : in    std_logic_vector(size - 1 downto 0);
      lut     : in    std_logic_vector((lut_size * size) - 1 downto 0);
      coefs_x : out   std_logic_vector((lut_size * size) - 1 downto 0);
      coefs_y : out   std_logic_vector((lut_size * size) - 1 downto 0);
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

  -- Multiplier

  signal prod_z,     prod_z_norm : std_logic_vector(24 downto 0);
  signal prod_mod                : std_logic_vector(24 downto 0);
  signal mul_a                   : std_logic_vector(24 downto 0);
  signal mul_a_nex               : std_logic_vector(24 downto 0);
  signal mul_b                   : std_logic_vector(24 downto 0);
  signal mul_b_nex               : std_logic_vector(24 downto 0);
  signal mul_b_nex_sel           : std_logic_vector(24 downto 0);
  signal mul_coefs_x             : std_logic_vector((lut_size * 25) - 1 downto 0);
  signal mul_coefs_y             : std_logic_vector((lut_size * 25) - 1 downto 0);
  signal neg_mul_coefs_x         : std_logic_vector((lut_size * 25) - 1 downto 0);
  signal neg_mul_coefs_y         : std_logic_vector((lut_size * 25) - 1 downto 0);

  -- Output
  signal p_coefs_nex_x : std_logic_vector((lut_size * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_nex_y : std_logic_vector((lut_size * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_x_s   : std_logic_vector((lut_size * 25) - 1 downto 0) := (OTHERS => '0');
  signal p_coefs_y_s   : std_logic_vector((lut_size * 25) - 1 downto 0) := (OTHERS => '0');

begin

  -- Control unit

  uc : component hadamard_uc
    port map (
		clock,
 start,
 reset,
 mul_ready,
 j_end,
 load_change,
 cordic_feedback,
		flux_to_cordic,
 freeze_terms,
 mul_xy,
 cordic_rotation,
 ready
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
	  5, 25
    )
    port map (
		sc_sig_cur,
 '0',
		j,
		sc_x_cur,
 sc_y_cur,
		sc_z_cur,
		sc_x_cor,
 sc_y_cor,
		sc_z_cor,
		sc_sig_cor
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
		5, 25
    )
    port map (
		pc_sig_cur,
 cordic_rotation,
		j,
		pc_x_cur,
 pc_y_cur,
		pc_z_cur,
		pc_x_cor,
 pc_y_cor,
		pc_z_cor,
		pc_sig_cor
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

  prod_z           <= std_logic_vector(unsigned(pc_z_cur) + unsigned(sc_z_cur));
  prod_z_norm      <= '0' & prod_z(23 downto 0);
  increment_change <= prod_z(24);

  -- OBS: check if run can be left at high
  flux_mul : component flux_multiplier
    generic map (
25, 16, lut_size
    )
    port map (
		clock,
 reset,
 '1',
		mul_a,
 mul_b,
 mul_a_nex,
 mul_b_nex,
		lut,
		mul_coefs_x,
		mul_coefs_y,
		prod_mod,
		mul_ready
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

  gen_mul_negs : for i IN 0 to lut_size - 1 generate
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
