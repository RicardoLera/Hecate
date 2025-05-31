  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  port (
    clock : in  std_logic;
    reset : in  std_logic;
    start : in  std_logic;
    x_i   : in  std_logic_vector(24 downto 0);
    y_i   : in  std_logic_vector(24 downto 0);
    x_k   : in  std_logic_vector(24 downto 0);
    y_k   : in  std_logic_vector(24 downto 0);
    p     : out b25_complex;
    ready : out std_logic
  );
end entity hadamard;

architecture synth of hadamard is

  -- Control unit
  signal j_end, mul_ready, rotation : std_logic;
  signal cordic_mode, flux_mode     : std_logic_vector(1 downto 0);
  signal run_flux        : std_logic := '0';

  -- CORDIC control
  signal j : unsigned(cordic_len_log-1 downto 0) := (others => '0');

  -- Sign treatment
  signal x_i_abs, y_i_abs     : std_logic_vector(24 downto 0);
  signal x_k_abs, y_k_abs     : std_logic_vector(24 downto 0);
  signal img_z,  ker_z        : std_logic_vector(24 downto 0) := (others => '0');
  signal img_pi, ker_pi       : std_logic_vector(24 downto 0);
  signal img_z_cor, ker_z_cor : std_logic_vector(24 downto 0);
  signal prod_x, prod_y       : std_logic;

  -- Primary CORDIC
  signal pc_x_in, pc_y_in, pc_z_in    : std_logic_vector(24 downto 0) := (others => '0');
  signal pc_x_out, pc_y_out, pc_z_out : std_logic_vector(24 downto 0);
  signal pc_sig_in, pc_sig_out        : std_logic := '0';

  -- Secondary CORDIC
  signal sc_x_in, sc_y_in, sc_z_in    : std_logic_vector(24 downto 0) := (others => '0');
  signal sc_x_out, sc_y_out, sc_z_out : std_logic_vector(24 downto 0);
  signal sc_sig_in, sc_sig_out        : std_logic := '0';

  -- Multipliers
  signal prod_r, prod_r_l         : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_z, prod_pi          : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_z_mod, prod_z_mux   : std_logic_vector(24 downto 0) := (others => '0');
  signal prod_z_cor, prod_z_cor_l : std_logic_vector(24 downto 0) := (others => '0');
  signal mul_a, mul_a_nex         : std_logic_vector(23 downto 0) := (others => '0');
  signal mul_b, mul_b_nex         : std_logic_vector(23 downto 0) := (others => '0');
  signal prod_quadrant            : std_logic_vector( 1 downto 0) := (others => '0');
  signal kmul_in_x, kmul_out_x    : std_logic_vector(24 downto 0) := (others => '0');
  signal kmul_in_y, kmul_out_y    : std_logic_vector(24 downto 0) := (others => '0');

  -- Output
  signal out_x_sel, out_y_sel     : std_logic_vector(24 downto 0);

begin

  -- Control Unit
  uc : component hadamard_uc
    port map (
      clock       => clock,
      start       => start,
      reset       => reset,
      mul_ready   => mul_ready,
      cordic_mode => cordic_mode,
      flux_mode   => flux_mode,
      rotation    => rotation,
      ready       => ready
    );

  -- Flux Multiplier
  flux_mul : component flux_multiplier
    port map (
      clock     => clock,
      reset     => (mul_ready and j_end) or reset,
      run       => run_flux,
      a         => mul_a,
      b         => mul_b,
      a_nex     => mul_a_nex,
      b_nex     => mul_b_nex,
      p         => prod_r,
      ready     => mul_ready
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
  kmul_x : component b25_kmul
    generic map (
      con => b25_kcon
    )
    port map (
      a   => kmul_in_x,
      res => kmul_out_x
    );
  kmul_y : component b25_kmul
    generic map (
      con => b25_kcon
    )
    port map (
      a   => kmul_in_y,
      res => kmul_out_y
    );


  -- i/k normalization to Q1 (signs preserved in input)

  x_i_abs <= '0' & x_i(23 downto 0);
  y_i_abs <= '0' & y_i(23 downto 0);
  x_k_abs <= '0' & x_k(23 downto 0);
  y_k_abs <= '0' & y_k(23 downto 0);



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



  -- Primary CORDIC process and signals

  pc_cor_pro : process (clock) begin
    if rising_edge(clock) then

      if (mul_ready) then -- latch
        prod_r_l <= prod_r;
        prod_z_cor_l <= prod_z_cor;
      end if;

      case cordic_mode is
        when "01" =>
          pc_x_in   <= x_i_abs;
          pc_y_in   <= y_i_abs;
          pc_z_in   <= 25x"0";
          pc_sig_in <= not rotation;
          kmul_in_x <= (others => '0');
          kmul_in_y <= (others => '0');

        when "10" =>
          pc_x_in   <= pc_x_out;
          pc_y_in   <= pc_y_out;
          pc_z_in   <= pc_z_out;
          pc_sig_in <= pc_sig_out;
          kmul_in_x <= pc_x_out;      -- Might cause unnecesary power usage
          kmul_in_y <= pc_y_out;


        when "11" =>
          pc_x_in   <= prod_r_l;
          pc_y_in   <= (others => '0');
          pc_z_in   <= prod_z_cor_l;
          pc_sig_in <= not rotation;
          kmul_in_x <= (others => '0');
          kmul_in_y <= (others => '0');

        when others =>
          pc_x_in   <= pc_x_in;
          pc_y_in   <= pc_y_in;
          pc_z_in   <= pc_z_in;
          pc_sig_in <= pc_sig_in;
          kmul_in_x <= pc_x_out;
          kmul_in_y <= pc_y_out;
      end case;
    end if;
  end process pc_cor_pro;



  -- Secondary CORDIC process and signals

  sc_cor_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "01" =>
          sc_x_in   <= x_k_abs;
          sc_y_in   <= y_k_abs;
          sc_z_in   <= 25x"0";
          sc_sig_in <= '1';

        when "10" =>
          sc_x_in   <= sc_x_out;
          sc_y_in   <= sc_y_out;
          sc_z_in   <= sc_z_out;
          sc_sig_in <= sc_sig_out;

        when "11" =>
          sc_x_in   <= 25x"0";
          sc_y_in   <= 25x"0";
          sc_z_in   <= 25x"0";
          sc_sig_in <= '0';

        when others =>
          sc_x_in   <= sc_x_in;
          sc_y_in   <= sc_y_in;
          sc_z_in   <= sc_z_in;
          sc_sig_in <= sc_sig_in;
      end case;
    end if;
  end process sc_cor_pro;



  -- Flux Multiplier Signals

  flux_pro : process (clock) begin
    if rising_edge(clock) then
      case flux_mode is
        when "00" =>
          mul_a     <= 24x"0";
          mul_b     <= 24x"0";
          mul_a_nex <= 24x"0";
          mul_b_nex <= 24x"0";
          run_flux  <= '0';

        when "01" =>
          mul_a     <= pc_x_in(23 downto 0);
          mul_b     <= sc_x_in(23 downto 0);
          mul_a_nex <= pc_x_out(23 downto 0);
          mul_b_nex <= sc_x_out(23 downto 0);
          run_flux  <= '1';

        when "10" =>
          mul_a     <= pc_x_in(23 downto 0);
          mul_b     <= pc_y_in(23 downto 0);
          mul_a_nex <= pc_x_out(23 downto 0);
          mul_b_nex <= pc_y_out(23 downto 0);
          run_flux  <= '1';

        when others =>
          mul_a     <= mul_a;
          mul_b     <= mul_b;
          mul_a_nex <= mul_a_nex;
          mul_b_nex <= mul_b_nex;
          run_flux  <= '1';
      end case;
    end if;
  end process flux_pro;



  -- i/k correction to Q1~4

  corr_latch : process (reset, clock) begin
    if (reset) then
      img_z(23 downto 0) <= (others => '0');
      ker_z(23 downto 0) <= (others => '0');
    elsif rising_edge(clock) then
        if (j_end = '1') and flux_mode = "01" then
        img_z(23 downto 0) <= pc_z_in(23 downto 0);
        ker_z(23 downto 0) <= sc_z_in(23 downto 0);
      end if;
    end if;
  end process corr_latch;

  with std_logic_vector'(x_i(24) & y_i(24)) select img_z(24) <=
    '0' when "00",   -- QTR
    '1' when "10",   -- QTL
    '0' when "11",   -- QBL
    '1' when others; -- QBR

  with std_logic_vector'(x_k(24) & y_k(24)) select ker_z(24) <=
    '0' when "00",   -- QTR
    '1' when "10",   -- QTL
    '0' when "11",   -- QBL
    '1' when others; -- QBR

  with std_logic_vector'(x_i(24) & y_i(24)) select img_pi <=
    '0' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '0' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  with std_logic_vector'(x_k(24) & y_k(24)) select ker_pi <=
    '0' & 24b"0"   when "00",   -- QTR
    '0' & pi24     when "10",   -- QTL
    '0' & pi24     when "11",   -- QBL
    '0' & two_pi24 when others; -- QBR

  img_correction : component b25_add
    port map (
      a   => img_z,
      b   => img_pi,
      res => img_z_cor
    );

  ker_correction : component b25_add
    port map (
      a   => ker_z,
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
  
  z_mod : component b25_add
    port map (
      a   => prod_z,
      b   => '1' & two_pi24(23 downto 0),
      res => prod_z_mod
    );

  prod_z_mux(23 downto 0) <=
    prod_z_mod(23 downto 0) when (unsigned(prod_z(23 downto 0)) > unsigned(two_pi24)) else
    prod_z(23 downto 0);

  prod_quadrant <=
    "00" when (unsigned(prod_z_mux(23 downto 0)) < unsigned(half_pi24)      ) else
    "01" when (unsigned(prod_z_mux(23 downto 0)) < unsigned(pi24)           ) else
    "10" when (unsigned(prod_z_mux(23 downto 0)) < unsigned(three_half_pi24)) else
    "11";
  
  with prod_quadrant select prod_z_mux(24) <=
    '0' when "00",
    '1' when "01",
    '0' when "10",
    '1' when others;
  
  with prod_quadrant select prod_pi <=
    '0' & 24b"0"   when "00",
    '0' & pi24     when "01",
    '1' & pi24     when "10",
    '0' & two_pi24 when others;

  z_correction : component b25_add
    port map (
      a   => prod_z_mux,
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

  with prod_x select out_x_sel <=
    kmul_out_x when '0',
    (not kmul_out_x(24) & kmul_out_x(23 downto 0)) when others;

  with prod_y select out_y_sel <=
    kmul_out_y when '0',
    (not kmul_out_y(24) & kmul_out_y(23 downto 0)) when others;

  outp_reg : process (clock) begin
    if rising_edge(clock) then
      if (ready = '0') then
        p <= (out_x_sel, out_y_sel);
      end if;
    end if;
  end process outp_reg;

end architecture synth;