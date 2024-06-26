library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  generic (
    n_idx : natural range 0 to 16 := 0
  );
  port (
    clock     : in    std_logic;
    reset     : in    std_logic;
    start     : in    std_logic;
    x_i       : in    std_logic_vector(24 downto 0);
    y_i       : in    std_logic_vector(24 downto 0);
    x_k       : in    std_logic_vector(24 downto 0);
    y_k       : in    std_logic_vector(24 downto 0);
    p_coefs_x : out   b25_real_array(0 to 7);
    p_coefs_y : out   b25_real_array(0 to 7);
    ready     : buffer std_logic
  );
end entity hadamard;

architecture arch of hadamard is

  -- Control unit
  signal mul_ready       : std_logic;
  signal cordic_feedback : std_logic;
  signal freeze_cordic   : std_logic;
  signal flux_to_cordic  : std_logic;
  signal cordic_rotation : std_logic;
  signal flux_coefs      : std_logic;

  -- J control
  signal j     : std_logic_vector(4 downto 0) := (others => '0');
  signal j_end : std_logic;

  -- Sign treatment
  signal x_i_abs, y_i_abs, x_k_abs, y_k_abs : std_logic_vector(24 downto 0);
  signal img_z,  ker_z                      : std_logic_vector(24 downto 0) := (others => '0');
  signal img_pi, ker_pi                     : std_logic_vector(24 downto 0);
  signal img_z_cor, ker_z_cor               : std_logic_vector(24 downto 0);
  signal prod_x, prod_y                     : std_logic;

  -- Primary CORDIC
  signal pc_x_cur, pc_y_cur, pc_z_cur       : std_logic_vector(24 downto 0) := (others => '0');
  signal pc_x_nex, pc_y_nex, pc_z_nex       : std_logic_vector(24 downto 0);
  signal pc_x_out, pc_y_out, pc_z_out       : std_logic_vector(24 downto 0);
  signal pc_sig_cur, pc_sig_nex, pc_sig_out : std_logic;
  signal pc_x_sel, pc_y_sel, pc_z_sel       : std_logic_vector(24 downto 0);

  -- Secondary CORDIC
  signal sc_x_cur, sc_y_cur, sc_z_cur       : std_logic_vector(24 downto 0) := (others => '0');
  signal sc_x_nex, sc_y_nex, sc_z_nex       : std_logic_vector(24 downto 0);
  signal sc_x_out, sc_y_out, sc_z_out       : std_logic_vector(24 downto 0);
  signal sc_sig_cur, sc_sig_nex, sc_sig_out : std_logic;

  -- Multiplier
  signal prod_r                          : std_logic_vector(24 downto 0);
  signal prod_z, prod_pi, prod_z_cor     : std_logic_vector(24 downto 0);
  signal prod_quadrant                   : std_logic_vector(1 downto 0);
  signal mul_a, mul_a_nex                : std_logic_vector(24 downto 0);
  signal mul_b, mul_b_nex, mul_b_nex_sel : std_logic_vector(24 downto 0);
  signal coefs_x, neg_coefs_x            : b25_real_array(0 to 7);
  signal coefs_y, neg_coefs_y            : b25_real_array(0 to 7);

  -- Output
  signal coefs_x_sel, coefs_y_sel : b25_real_array(0 to 7);
  signal p_coefs_x_s, p_coefs_y_s : b25_real_array(0 to 7) := (others => (others => '0'));

begin

  -- Control Unit
  uc : component hadamard_uc
    port map (
      clock           => clock,
      start           => start,
      reset           => reset,
      j_end           => j_end,
      mul_ready       => mul_ready,
      cordic_feedback => cordic_feedback,
      freeze_cordic   => freeze_cordic,
      flux_to_cordic  => flux_to_cordic,
      cordic_rotation => cordic_rotation,
      flux_coefs      => flux_coefs,
      ready           => ready
    );

  -- Flux Multiplier
  flux_mul : component flux_multiplier
    generic map (
      n_idx => n_idx
    )
    port map (
      clock     => clock,
      reset     => (mul_ready and j_end) or reset,
      run       => start,
      run_coefs => flux_coefs,
      a         => mul_a,
      b         => mul_b,
      a_nex     => mul_a_nex,
      b_nex     => mul_b_nex,
      coefs_x   => coefs_x,
      coefs_y   => coefs_y,
      p         => prod_r,
      ready     => mul_ready
    );

  -- Primary CORDIC
  pri_cordic : component cordic
    generic map (
      j_len => 5, coords_len => 25
    )
    port map (
      sigma_in  => pc_sig_cur,
      rotation  => cordic_rotation,
      j         => j,
      x_in      => pc_x_cur,
      y_in      => pc_y_cur,
      z_in      => pc_z_cur,
      x_out     => pc_x_out,
      y_out     => pc_y_out,
      z_out     => pc_z_out,
      sigma_out => pc_sig_out
    );
  
  -- Secondary CORDIC     
  sec_cordic : component cordic
    generic map (
      j_len => 5, coords_len => 25
    )
    port map (
      sigma_in  => sc_sig_cur,
      rotation  => '0',
      j         => j,
      x_in      => sc_x_cur,
      y_in      => sc_y_cur,
      z_in      => sc_z_cur,
      x_out     => sc_x_out,
      y_out     => sc_y_out,
      z_out     => sc_z_out,
      sigma_out => sc_sig_out
    );



  -- i/k normalization to Q1 (signs preserved in input)

  x_i_abs <= '0' & x_i(23 downto 0);
  y_i_abs <= '0' & y_i(23 downto 0);
  x_k_abs <= '0' & x_k(23 downto 0);
  y_k_abs <= '0' & y_k(23 downto 0);



  -- J control (both CORDICs)

  j_control_pro : process (clock) is
  begin
    if rising_edge(clock) then
      if (cordic_feedback = '1') then
        if (unsigned(j) < to_unsigned(24 +2, 5)) then  -- modifier to sync kx
          j <= std_logic_vector(unsigned(j) + to_unsigned(1, 5));
        else
          j <= (others => '0');
          j_end <= '1';
        end if;
      else
        j <= (others => '0');
        j_end <= '0';
      end if;
    end if;
  end process j_control_pro;

  

  -- Primary CORDIC process and signals

  pc_cor_pro : process (clock) is
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        pc_x_cur   <= (others => '0');
        pc_y_cur   <= (others => '0');
        pc_z_cur   <= (others => '0');
        pc_sig_cur <= '0';
      elsif (freeze_cordic = '0') then
        pc_x_cur   <= pc_x_nex;
        pc_y_cur   <= pc_y_nex;
        pc_z_cur   <= pc_z_nex;
        pc_sig_cur <= pc_sig_nex;
      end if;
    end if;
  end process pc_cor_pro;

  with cordic_feedback select pc_x_sel <=
    pc_x_out when '1',
    x_i_abs when others;
  with cordic_feedback select pc_y_sel <=
    pc_y_out when '1',
    y_i_abs when others;
  with cordic_feedback select pc_z_sel <=
    pc_z_out when '1',
    (others => '0') when others;
  with cordic_feedback select pc_sig_nex <=
    pc_sig_out when '1',
    (not cordic_rotation) when others;

  -- Flux_to_cordic -> Pre-rotation
  with flux_to_cordic select pc_x_nex <=
    pc_x_sel when '0',
    prod_r when others;
  with flux_to_cordic select pc_y_nex <=
    pc_y_sel when '0',
    (others => '0') when others;
  with flux_to_cordic select pc_z_nex <=
    pc_z_sel when '0',
    prod_z_cor when others;
  


  -- Secondary CORDIC process and signals

  sc_cor_pro : process (clock) is
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        sc_x_cur   <= (others => '0');
        sc_y_cur   <= (others => '0');
        sc_z_cur   <= (others => '0');
        sc_sig_cur <= '0';
      elsif (freeze_cordic = '0') then
        sc_x_cur   <= sc_x_nex;
        sc_y_cur   <= sc_y_nex;
        sc_z_cur   <= sc_z_nex;
        sc_sig_cur <= sc_sig_nex;
      end if;
    end if;
  end process sc_cor_pro;

  with cordic_feedback select sc_x_nex <=
    sc_x_out when '1',
    x_k_abs when others;
  with cordic_feedback select sc_y_nex <=
    sc_y_out when '1',
    y_k_abs when others;
  with cordic_feedback select sc_z_nex <=
    sc_z_out when '1',
    (others => '0') when others;
  with cordic_feedback select sc_sig_nex <=
    sc_sig_out when '1',
    '1' when others;



  -- Flux Multiplier Signals

  mul_a <= pc_x_cur;

  with flux_coefs select mul_b <=
    pc_y_cur when '1',
    sc_x_cur when others;

  with freeze_cordic select mul_a_nex <=
    mul_a when '1',
    pc_x_out when others;

  with freeze_cordic select mul_b_nex <=
    mul_b when '1',
    mul_b_nex_sel when others;

  with flux_coefs select mul_b_nex_sel <=
    pc_y_nex when '1',
    sc_x_nex when others;



  -- i/k correction to Q1~4

  pm_latch : process (j_end) is
  begin
    if rising_edge(j_end) then
      if (cordic_rotation = '0') then
        img_z <= pc_z_cur;
        ker_z <= sc_z_cur;
      end if;
    end if;
  end process pm_latch;

  with std_logic_vector'(x_i(24) & y_i(24)) select img_pi <=
    '1' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '1' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  with std_logic_vector'(x_k(24) & y_k(24)) select ker_pi <=
    '1' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '1' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  img_correction : component b25_add
    port map (
      a   => not img_pi(24) & img_z(23 downto 0),
      b   => img_pi,
      res => img_z_cor
    );

  ker_correction : component b25_add
    port map (
      a   => not ker_pi(24) & ker_z(23 downto 0),
      b   => ker_pi,
      res => ker_z_cor
    );



  -- Polar Multiplication (angle z) -- Normalization to Q1

  z_addition : component b25_add
    port map (
      a   => img_z_cor,
      b   => ker_z_cor,
      res => prod_z
    );

  prod_quadrant <=
    "00" when (unsigned(prod_z(23 downto 0)) < unsigned(half_pi24)      ) else
    "01" when (unsigned(prod_z(23 downto 0)) < unsigned(pi24)           ) else
    "10" when (unsigned(prod_z(23 downto 0)) < unsigned(three_half_pi24)) else
    "11";
  
  with prod_quadrant select prod_pi <=
    '1' & 24b"0" when "00",
    '0' & pi24 when "01",
    '1' & pi24 when "10",
    '0' & two_pi24 when others;

  z_correction : component b25_add
    port map (
      a   => not prod_pi(24) & prod_z(23 downto 0),
      b   => prod_pi,
      res => prod_z_cor
    );
  
  with prod_quadrant select prod_x <=
    '0' when "00",
    '1' when "01",
    '1' when "10",
    '0' when others;

  with prod_quadrant select prod_y <=
    '0' when "00",
    '0' when "01",
    '1' when "10",
    '1' when others;


  
  -- Apply normalization to output

  gen_mul_negs : for i in 0 to 7 generate
    neg_coefs_x(i) <= not coefs_x(i)(24) & coefs_x(i)(23 downto 0);
    neg_coefs_y(i) <= not coefs_y(i)(24) & coefs_y(i)(23 downto 0);
  end generate gen_mul_negs;

  with prod_x select coefs_x_sel <=
    coefs_x when '0',
    neg_coefs_x when others;

  with prod_y select coefs_y_sel <=
    coefs_y when '0',
    neg_coefs_y when others;

  outp_reg : process (clock) is
  begin
    if rising_edge(clock) then
      if (ready = '0') then
          p_coefs_x_s <= coefs_x_sel;
          p_coefs_y_s <= coefs_y_sel;
      end if;
    end if;
  end process outp_reg;

  p_coefs_x <= p_coefs_x_s;
  p_coefs_y <= p_coefs_y_s;

end architecture arch;


  -- with (x_i(x_i'length - 1) xor y_i(y_i'length - 1)) select x_i_n <=     wat?
  --   y_i_abs when '1',
  --   x_i_abs when others;

  -- with (x_i(x_i'length - 1) xor y_i(y_i'length - 1)) select y_i_n <=
  --   x_i_abs when '1',
  --   y_i_abs when others;