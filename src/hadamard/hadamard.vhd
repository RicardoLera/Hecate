  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard is
  port (
    clock, reset, start : in  std_logic;
    img, ker            : in  t_signed_complex;
    p                   : out t_signed_complex;
    ready               : out std_logic
  );
end entity hadamard;

architecture synth of hadamard is

  -- Control unit
  signal j_end, rotation, polar_latch_ready : std_logic;
  signal cordic_mode                        : std_logic_vector(1 downto 0);
  signal flux_run, kx_run                   : std_logic := '0';

  -- CORDIC control
  signal j : integer range 0 to cordic_len := 0;

  -- Primary CORDIC
  signal pc_x_in, pc_y_in      : t_signed := (others => '0');
  signal pc_x_out, pc_y_out    : t_signed;
  signal pc_sig_in, pc_sig_out : std_logic := '0';
  signal pc_z_in, pc_z_out     : t_pfb;

  -- Secondary CORDIC
  signal sc_x_in, sc_y_in      : t_signed := (others => '0');
  signal sc_x_out, sc_y_out    : t_signed;
  signal sc_sig_in, sc_sig_out : std_logic := '0';
  signal sc_z_in, sc_z_out     : t_pfb;

  -- Flux Multiplier
  signal flux_a, flux_a_nex : t_signed := (others => '0');
  signal flux_b, flux_b_nex : t_signed := (others => '0');
  signal flux_ready         : std_logic;
  signal flux_out           : t_signed := (others => '0');

  -- Feedback latches
  signal img_z_l, ker_z_l : t_pfb := (others => '0');
  signal prod_l           : t_signed := (others => '0');

  -- Sign treatment
  signal img_x_abs, img_y_abs : t_signed;
  signal ker_x_abs, ker_y_abs : t_signed;
  signal img_z_cor, ker_z_cor : t_pfb;
  signal prod_z, prod_z_q1    : t_pfb := (others => '0');
  signal img_quad, ker_quad   : signed(1 downto 0);

  -- K-correction Constant Multipliers
  signal kmul_in_x, kmul_out_x : t_signed := (others => '0');
  signal kmul_in_y, kmul_out_y : t_signed := (others => '0');
  signal out_x_sel, out_y_sel  : t_signed;

begin

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
      a     => flux_a,
      b     => flux_b,
      a_nex => flux_a_nex,
      b_nex => flux_b_nex,
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
  kmul_out_x <= resize((kmul_in_x * signed_kcon) sra signed_point, signed_size);
  kmul_out_y <= resize((kmul_in_y * signed_kcon) sra signed_point, signed_size);

  -- J control (both CORDICs)
  j_control_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "10" =>
          if (j < cordic_len-1) then
            j <= j + 1;
          end if;
        when "01"   => j <= 0;
        when "11"   => j <= 0;
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
          pc_z_in   <= prod_z_q1;
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
        img_z_l <= pc_z_out;
        ker_z_l <= sc_z_out;
        polar_latch_ready <= '1';
      else 
        polar_latch_ready <= '0';
      end if;
    end if;
  end process latch_pro;


  --=== SIGN NORMALIZATION ===--
  
  -- Pre-CORDIC i/k normalization to Q1 (signs preserved in input)
  img_x_abs <= abs(img(0));
  img_y_abs <= abs(img(1));
  ker_x_abs <= abs(ker(0));
  ker_y_abs <= abs(ker(1));

  -- Post-vectorization i/k correction to Q1~4
  img_quad <= (img(1)(signed_size-1), img(0)(signed_size-1) xor img(1)(signed_size-1));
  ker_quad <= (ker(1)(signed_size-1), ker(0)(signed_size-1) xor ker(1)(signed_size-1));

  img_q : component pfb_q
    port map (
      a   => img_z_l,
      qt  => img_quad,
      res => img_z_cor
    );

  ker_q : component pfb_q
    port map (
      a   => ker_z_l,
      qt  => ker_quad,
      res => ker_z_cor
    );

  -- Polar Multiplication (angle z) -- Normalization to Q1
  prod_z <= img_z_cor + ker_z_cor;

  prod_q : component pfb_q
    port map (
      a   => prod_z,
      qt  => "00",
      res => prod_z_q1
    );

  -- Apply normalization to output
  with (prod_z(pfb_size-1) xor prod_z(pfb_size-2)) select out_x_sel <= -- q01 and q10
    -kmul_out_x when '1',
    kmul_out_x when others;

  with (prod_z(pfb_size-1)) select out_y_sel <= -- q10 and q11
    -kmul_out_y when '1',
    kmul_out_y when others;

  p <= (out_x_sel, out_y_sel);
end architecture synth;