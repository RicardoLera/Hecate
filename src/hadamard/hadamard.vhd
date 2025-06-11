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
  signal j_end, rotation, polar_latch_ready : std_logic := '0';
  signal cordic_mode                        : std_logic_vector(1 downto 0) := (others => '0');
  signal flux_run, flux_reset, kx_run       : std_logic := '0';

  -- CORDIC control
  signal j : integer range 0 to cordic_len := 0;

  -- CORDIC feedback latches
  signal img_z_l, ker_z_l : t_pfb    := (others => '0');
  signal prod_l           : t_signed := (others => '0');

  -- Primary CORDIC
  signal pc_x_in, pc_y_in      : t_signed  := (others => '0');
  signal pc_x_out, pc_y_out    : t_signed  := (others => '0');
  signal pc_sig_in, pc_sig_out : std_logic := '0';
  signal pc_z_in, pc_z_out     : t_pfb     := (others => '0');
  signal pc_comp_out           : std_logic := '0';

  -- Secondary CORDIC
  signal sc_x_in, sc_y_in      : t_signed  := (others => '0');
  signal sc_x_out, sc_y_out    : t_signed  := (others => '0');
  signal sc_sig_in, sc_sig_out : std_logic := '0';
  signal sc_z_in, sc_z_out     : t_pfb     := (others => '0');
  signal sc_comp_out           : std_logic := '0';

  -- Flux Multiplier
  signal flux_a, flux_a_nex : t_signed  := (others => '0');
  signal flux_b, flux_b_nex : t_signed  := (others => '0');
  signal flux_ready         : std_logic := '0';
  signal flux_out           : t_signed  := (others => '0');

  -- PFB sign treatment
  signal img_x_abs, img_y_abs : t_signed  := (others => '0');
  signal ker_x_abs, ker_y_abs : t_signed  := (others => '0');
  signal prod_z0              : t_pfb     := (others => '0');
  signal prod_xs, prod_ys     : std_logic := '0';

  -- K-correction Constant Multipliers
  signal kmul_in_x, kmul_out_x : t_signed := (others => '0');
  signal kmul_in_y, kmul_out_y : t_signed := (others => '0');
  signal out_x_sel, out_y_sel  : t_signed := (others => '0');

begin

  -- Control Unit
  cu : component hadamard_cu
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
      flux_reset        => flux_reset,
      kx_run            => kx_run
    );

  -- Flux Multiplier
  flux_mul : component flux_multiplier
    port map (
      clock => clock,
      reset => flux_reset,
      run   => flux_run,
      a     => flux_a,
      b     => flux_b,
      a_nex => flux_a_nex,
      b_nex => flux_b_nex,
      p     => flux_out,
      ready => flux_ready
    );

  -- Primary CORDIC -> Vectorization and Rotation
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
      sigma_out => pc_sig_out,
      comp_out  => pc_comp_out
    );
  
  -- Secondary CORDIC -> Vectorization  
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
      sigma_out => sc_sig_out,
      comp_out  => sc_comp_out
    );

  -- Angle Addition and Correction Unit
  aacu : component pfb_qadd
    port map (
      ax  => img(0),
      ay  => img(1),
      bx  => ker(0),
      by  => ker(1),
      az0 => img_z_l,
      bz0 => ker_z_l,
      sz0 => prod_z0,
      sxs => prod_xs,
      sys => prod_ys
    );

  -- K-correction Constant Multipliers
  kmul_out_x <= resize((kmul_in_x * signed_kcon) sra signed_point, signed_size);
  kmul_out_y <= resize((kmul_in_y * signed_kcon) sra signed_point, signed_size);



  
-- /\ Main component instantiations
--====================================================================================--
-- \/ Registers and signal assignments




  -- Pre-CORDIC i/k normalization to Q1 (signs preserved in input)
  img_x_abs <= resize(abs(img(0)), signed_size);
  img_y_abs <= resize(abs(img(1)), signed_size);
  ker_x_abs <= resize(abs(ker(0)), signed_size);
  ker_y_abs <= resize(abs(ker(1)), signed_size);

  -- J-control register and incrementer (both CORDICs)
  j_control_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "10" =>
          if (j < cordic_len-1) then
            j <= j + 1;
          end if;
        when others => j <= 0;
      end case;
    end if;
  end process j_control_pro;

  -- CORDIC polar coordinate feedback latch
  latch_pro : process (clock) begin
    if rising_edge(clock) then
      if (flux_run and flux_ready and j_end) then -- at vector_flux, when flux_mul and both cordics are ready
        prod_l  <= flux_out;
        img_z_l <= pc_z_out;
        ker_z_l <= sc_z_out;
        polar_latch_ready <= '1';
      else 
        polar_latch_ready <= '0';
      end if;
    end if;
  end process latch_pro;

  -- Primary CORDIC signal registers
  pc_cor_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "01" => -- Set initials (rect -> polar)
          pc_x_in   <= img_x_abs;
          pc_y_in   <= img_y_abs;
          pc_z_in   <= (others => '0');
          pc_sig_in <= not rotation;

        when "10" => -- Feedback
          pc_x_in   <= pc_x_out;
          pc_y_in   <= pc_y_out;
          pc_z_in   <= pc_z_out;
          pc_sig_in <= pc_sig_out;
          kmul_in_x <= pc_x_out;
          kmul_in_y <= pc_y_out;

        when "11" => -- Set product (polar -> rect)
          pc_x_in   <= prod_l;
          pc_y_in   <= (others => '0');
          pc_z_in   <= prod_z0;
          pc_sig_in <= not rotation;

        when others => -- off
          pc_x_in   <= (others => '0');
          pc_y_in   <= (others => '0');
          pc_z_in   <= (others => '0');
          pc_sig_in <= '0';
          kmul_in_x <= (others => '0');
          kmul_in_y <= (others => '0');
      end case;
    end if;
  end process pc_cor_pro;

  -- Secondary CORDIC signal registers
  sc_cor_pro : process (clock) begin
    if rising_edge(clock) then
      case cordic_mode is
        when "01" => -- Set initials (rect -> polar)
          sc_x_in   <= ker_x_abs;
          sc_y_in   <= ker_y_abs;
          sc_z_in   <= (others => '0');
          sc_sig_in <= '1';

        when "10" => -- Feedback
          sc_x_in   <= sc_x_out;
          sc_y_in   <= sc_y_out;
          sc_z_in   <= sc_z_out;
          sc_sig_in <= sc_sig_out;

        when others => -- off
          sc_x_in   <= (others => '0');
          sc_y_in   <= (others => '0');
          sc_z_in   <= (others => '0');
          sc_sig_in <= '0';
      end case;
    end if;
  end process sc_cor_pro;

  -- CORDIC finish / premature-finish flag 
  j_end <= '1' when (j = cordic_len-1) or ((pc_comp_out = '1') and (sc_comp_out = '1')) else '0';

  -- Flux Multiplier signal registers
  flux_pro : process (clock) begin
    if rising_edge(clock) then
      case flux_run is
        when '1' => -- Polar mul
          flux_a     <= pc_x_in ;
          flux_b     <= sc_x_in ;
          flux_a_nex <= pc_x_out;
          flux_b_nex <= sc_x_out;

        when others => -- off
          flux_a     <= (others => '0');
          flux_b     <= (others => '0');
          flux_a_nex <= (others => '0');
          flux_b_nex <= (others => '0');
      end case;
    end if;
  end process flux_pro;

  -- Output sign corrections
  with prod_xs select out_x_sel <=
    -kmul_out_x when '1',
    kmul_out_x when others;

  with (prod_ys) select out_y_sel <=
    -kmul_out_y when '1',
    kmul_out_y when others;

  p <= (out_x_sel, out_y_sel);

end architecture synth;