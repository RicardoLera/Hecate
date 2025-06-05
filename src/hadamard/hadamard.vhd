  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  port (
    clock : in  std_logic;
    reset : in  std_logic;
    start : in  std_logic;
    img   : in  s25_complex;
    ker   : in  s25_complex;
    p     : out s25_complex;
    ready : out std_logic
  );
end entity hadamard;

architecture synth of hadamard is

  -- I/O conversion
  signal img_slv, ker_slv, p_slv : b25_complex;

  -- Control unit
  signal j_end, rotation, polar_latch_ready : std_logic;
  signal cordic_mode                        : std_logic_vector(1 downto 0);
  signal flux_run, kx_run                   : std_logic := '0';

  -- CORDIC control
  signal j : unsigned(cordic_len_log-1 downto 0) := (others => '0');

  -- Primary CORDIC
  signal pc_x_in, pc_y_in, pc_z_in    : std_logic_vector(24 downto 0) := (others => '0');
  signal pc_x_out, pc_y_out, pc_z_out : std_logic_vector(24 downto 0);
  signal pc_sig_in, pc_sig_out        : std_logic := '0';

  -- Secondary CORDIC
  signal sc_x_in, sc_y_in, sc_z_in    : std_logic_vector(24 downto 0) := (others => '0');
  signal sc_x_out, sc_y_out, sc_z_out : std_logic_vector(24 downto 0);
  signal sc_sig_in, sc_sig_out        : std_logic := '0';

  -- Flux Multiplier
  signal flux_a, flux_a_nex : std_logic_vector(24 downto 0) := (others => '0');
  signal flux_b, flux_b_nex : std_logic_vector(24 downto 0) := (others => '0');
  signal flux_ready         : std_logic;
  signal flux_out           : std_logic_vector(24 downto 0) := (others => '0');

  -- Feedback latches
  signal img_z_l, ker_z_l : std_logic_vector(23 downto 0) := (others => '0');
  signal prod_l           : std_logic_vector(24 downto 0) := (others => '0');

  -- Sign treatment - img & ker
  signal img_x_abs, img_y_abs   : std_logic_vector(24 downto 0);
  signal ker_x_abs, ker_y_abs   : std_logic_vector(24 downto 0);
  signal img_pi, ker_pi         : std_logic_vector(24 downto 0);
  signal img_z_cor, ker_z_cor   : std_logic_vector(24 downto 0);
  signal img_z_sign, ker_z_sign : std_logic;

  -- Sign treatment - product
  signal prod_z, prod_pi          : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_z_mod, prod_z_sel   : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_z_mod_sel           : std_logic_vector(23 downto 0) := (others => '0');
  signal prod_quadrant            : std_logic_vector( 1 downto 0) := (others => '0');
  signal prod_z_cor               : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_x_flip, prod_y_flip : std_logic;

  -- K-correction Constant Multipliers
  signal kmul_in_x, kmul_out_x : std_logic_vector(24 downto 0) := (others => '0');
  signal kmul_in_y, kmul_out_y : std_logic_vector(24 downto 0) := (others => '0');
  signal out_x_sel, out_y_sel  : std_logic_vector(24 downto 0);

begin

  -- Input conversions (4 k-adders)
  img_slv(0)(24)          <= img(0)(24) ;
  img_slv(1)(24)          <= img(1)(24);
  img_slv(0)(23 downto 0) <= std_logic_vector(-img(0)(23 downto 0)) when img(0)(24) else std_logic_vector(img(0)(23 downto 0));
  img_slv(1)(23 downto 0) <= std_logic_vector(-img(1)(23 downto 0)) when img(1)(24) else std_logic_vector(img(1)(23 downto 0));
  ker_slv(0)(24)          <= ker(0)(24) ;
  ker_slv(1)(24)          <= ker(1)(24);
  ker_slv(0)(23 downto 0) <= std_logic_vector(-ker(0)(23 downto 0)) when ker(0)(24) else std_logic_vector(ker(0)(23 downto 0));
  ker_slv(1)(23 downto 0) <= std_logic_vector(-ker(1)(23 downto 0)) when ker(1)(24) else std_logic_vector(ker(1)(23 downto 0));

  -- Control Unit
  uc : component hadamard_uc
    port map (
      clock             => clock,
      start             => start,
      reset             => reset,
      polar_latch_ready => polar_latch_ready,
      j_end             => j_end,
      cordic_mode       => cordic_mode,
      ready             => ready,
      rotation          => rotation,
      flux_run          => flux_run,
      kx_run            => kx_run
    );

  -- Flux Multiplier
  flux_mul : component flux_multiplier
    port map (
      clock => clock,
      reset => reset,
      run   => flux_run,
      a     => flux_a(23 downto 0),
      b     => flux_b(23 downto 0),
      a_nex => flux_a_nex(23 downto 0),
      b_nex => flux_b_nex(23 downto 0),
      p     => flux_out,
      ready => flux_ready
    );

  -- Primary CORDIC
  pri_cordic : component cordic
    port map (
      sigma_in  => pc_sig_in,
      rotation  => rotation,
      j         => j,
      x_in      => pc_x_in,
      y_in      => pc_y_in,
      z_in      => pc_z_in,
      x_out     => pc_x_out,
      y_out     => pc_y_out,
      z_out     => pc_z_out,
      sigma_out => pc_sig_out
    );
  
  -- Secondary CORDIC     
  sec_cordic : component cordic
    port map (
      sigma_in  => sc_sig_in,
      rotation  => '0',
      j         => j,
      x_in      => sc_x_in,
      y_in      => sc_y_in,
      z_in      => sc_z_in,
      x_out     => sc_x_out,
      y_out     => sc_y_out,
      z_out     => sc_z_out,
      sigma_out => sc_sig_out
    );

  -- K-correction Constant Multipliers
  k_corr_x : component b25_kmul
    generic map (
      con => b25_kcon
    )
    port map (
      a   => kmul_in_x,
      res => kmul_out_x
    );

  k_corr_y : component b25_kmul
    generic map (
      con => b25_kcon
    )
    port map (
      a   => kmul_in_y,
      res => kmul_out_y
    );


  -- J control (both CORDICs)
  j_control_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "10" =>
          if (j < cordic_len-1) then
            j <= j + 1;
          end if;
        when "01"   => j <= (others => '0');
        when "11"   => j <= (others => '0');
        when others => j <= j;
      end case;
    end if;
  end process j_control_pro;
  j_end <= '1' when j = cordic_len-1 else '0';
    
  -- Primary CORDIC signals
  pc_cor_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "01" =>
          pc_x_in   <= img_x_abs;
          pc_y_in   <= img_y_abs;
          pc_z_in   <= (others => '0');
          pc_sig_in <= not rotation;

        when "10" =>
          pc_x_in   <= pc_x_out;
          pc_y_in   <= pc_y_out;
          pc_z_in   <= pc_z_out;
          pc_sig_in <= pc_sig_out;
          kmul_in_x <= pc_x_out;
          kmul_in_y <= pc_y_out;

        when "11" =>
          pc_x_in   <= prod_l;
          pc_y_in   <= (others => '0');
          pc_z_in   <= prod_z_cor;
          pc_sig_in <= not rotation;

        when others =>
          pc_x_in   <= (others => '0');
          pc_y_in   <= (others => '0');
          pc_z_in   <= (others => '0');
          pc_sig_in <= '0';
          kmul_in_x <= (others => '0');
          kmul_in_y <= (others => '0');
      end case;
    end if;
  end process pc_cor_pro;

  -- Secondary CORDIC signals
  sc_cor_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "01" =>
          sc_x_in   <= ker_x_abs;
          sc_y_in   <= ker_y_abs;
          sc_z_in   <= (others => '0');
          sc_sig_in <= '1';

        when "10" =>
          sc_x_in   <= sc_x_out;
          sc_y_in   <= sc_y_out;
          sc_z_in   <= sc_z_out;
          sc_sig_in <= sc_sig_out;

        when others =>
          sc_x_in   <= (others => '0');
          sc_y_in   <= (others => '0');
          sc_z_in   <= (others => '0');
          sc_sig_in <= '0';
      end case;
    end if;
  end process sc_cor_pro;

  -- Flux Multiplier Signals
  flux_pro : process (clock) begin
    if rising_edge(clock) then
    
      case flux_run is
        when '1' =>
          flux_a     <= pc_x_in ;
          flux_b     <= sc_x_in ;
          flux_a_nex <= pc_x_out;
          flux_b_nex <= sc_x_out;

        when others =>
          flux_a     <= (others => '0');
          flux_b     <= (others => '0');
          flux_a_nex <= (others => '0');
          flux_b_nex <= (others => '0');
      end case;
    end if;
  end process flux_pro;

  -- Latch polar coordinates for CORDIC feedback
  latch_pro : process (clock) begin
    if rising_edge(clock) then
      if (flux_run and flux_ready) then
        prod_l  <= flux_out;
        img_z_l <= pc_z_out(23 downto 0); -- or in?
        ker_z_l <= sc_z_out(23 downto 0); -- or in?
        polar_latch_ready <= '1';
      else 
        polar_latch_ready <= '0';
      end if;
    end if;
  end process latch_pro;


  --=== SIGN NORMALIZATION ===--
  
  -- Pre-CORDIC i/k normalization to Q1 (signs preserved in input)
  img_x_abs <= '0' & img_slv(0)(23 downto 0);
  img_y_abs <= '0' & img_slv(1)(23 downto 0);
  ker_x_abs <= '0' & ker_slv(0)(23 downto 0);
  ker_y_abs <= '0' & ker_slv(1)(23 downto 0);


  -- Post-vectorization i/k correction to Q1~4

  with std_logic_vector'(img(0)(24) & img(1)(24)) select img_z_sign <=
    '0' when "00",   -- QTR
    '1' when "10",   -- QTL
    '0' when "11",   -- QBL
    '1' when others; -- QBR

  with std_logic_vector'(ker(0)(24) & ker(1)(24)) select ker_z_sign <=
    '0' when "00",   -- QTR
    '1' when "10",   -- QTL
    '0' when "11",   -- QBL
    '1' when others; -- QBR

  with std_logic_vector'(img(0)(24) & img(1)(24)) select img_pi <=
    '0' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '0' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  with std_logic_vector'(ker(0)(24) & ker(1)(24)) select ker_pi <=
    '0' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '0' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  img_correction : component b25_add
    port map (
      a   => img_z_sign & img_z_l,
      b   => img_pi,
      res => img_z_cor
    );

  ker_correction : component b25_add
    port map (
      a   => ker_z_sign & ker_z_l,
      b   => ker_pi,
      res => ker_z_cor
    );


  -- Polar Multiplication (angle z) -- Normalization to Q1

  z_pmul : component b25_add
    port map (
      a   => img_z_cor,
      b   => ker_z_cor,
      res => prod_z
    );

  z_pi_mod : component b25_add
    port map (
      a   => prod_z,
      b   => '1' & two_pi24,
      res => prod_z_mod
    );

  z_corr : component b25_add
    port map (
      a   => prod_z_sel,
      b   => prod_pi,
      res => prod_z_cor
    );

  prod_z_mod_sel <=
    prod_z_mod(23 downto 0) when (prod_z > ('0' & two_pi24)) else
    prod_z(23 downto 0);

  prod_quadrant <=
    "00" when prod_z_mod_sel < half_pi24       else
    "01" when prod_z_mod_sel < pi24            else
    "10" when prod_z_mod_sel < three_half_pi24 else
    "11";
  
  with prod_quadrant select prod_z_sel <=
    '0' & prod_z_mod_sel when "00",
    '1' & prod_z_mod_sel when "01",
    '0' & prod_z_mod_sel when "10",
    '1' & prod_z_mod_sel when others;
  
  with prod_quadrant select prod_pi <=
    '0' & 24b"0"   when "00",
    '0' & pi24     when "01",
    '1' & pi24     when "10",
    '0' & two_pi24 when others;

  
  -- Apply normalization to output

  with prod_quadrant select prod_x_flip <=
    '0' when "00",
    '1' when "01",
    '1' when "10",
    '0' when others;

  with prod_quadrant select prod_y_flip <=
    '0' when "00",
    '0' when "01",
    '1' when "10",
    '1' when others;

  with prod_x_flip select out_x_sel <=
    kmul_out_x when '0',
    (not kmul_out_x(24) & kmul_out_x(23 downto 0)) when others;

  with prod_y_flip select out_y_sel <=
    kmul_out_y when '0',
    (not kmul_out_y(24) & kmul_out_y(23 downto 0)) when others;

  p_slv <= (out_x_sel, out_y_sel);

  p(0) <= resize(-signed(p_slv(0)(23 downto 0)), 25) when p_slv(0)(24) else resize(signed(p_slv(0)(23 downto 0)), 25);
  p(1) <= resize(-signed(p_slv(1)(23 downto 0)), 25) when p_slv(1)(24) else resize(signed(p_slv(1)(23 downto 0)), 25);

end architecture synth;