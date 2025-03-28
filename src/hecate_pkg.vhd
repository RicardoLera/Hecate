library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

  -- 25-bit types
  type b25_real_array is array (natural range <>) of std_logic_vector(24 downto 0);  -- maybe make these into records
  type b25_double_array is array (natural range <>) of std_logic_vector(49 downto 0);
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  type b25_complex_array is array (natural range <>) of b25_complex;

  type b25_2d_real_array is array (natural range <>) of b25_real_array;
  type b25_3d_real_array is array (natural range <>) of b25_2d_real_array;
  type b25_2d_complex_array is array (natural range <>) of b25_complex_array;
  type b25_3d_complex_array is array (natural range <>) of b25_2d_complex_array;

  -- Synth TB RAM
  type t_ram is array (natural range <>) of b25_real_array(0 to 26);

  -- Hadamard state list
  type t_state is (initial, vector_flux, pre_rot, rot_coef, final);

  -- 3d padding
  type padding is array(0 to 7) of natural range 0 to 32;
  constant pad3d : padding := (0, 1,  3,  4,  9,  10, 12, 13);
--constant pad3d : padding := (0, 16, 24, 4,  14, 10, 6,  22);

  -- DFT multiplication coeficient array
  type t_calc_vals_arr is array(0 to 31) of b25_real_array(0 to 7);

  -- DFT rotation reference
  type t_cos_val_ref is array(0 to 31) of natural range 0 to 8;
  constant cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1); -- Assuming no DFT-IDFT inversion
  constant cos_sig_ref : t_cos_val_ref := (0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0);
  constant sin_sig_ref : t_cos_val_ref := (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

  -- DFT omega constants
  constant c_base : real := MATH_PI/16.0;
  constant w_cos1 : unsigned := to_unsigned(natural(65536.0*cos(1.0 * c_base)), 17);
  constant w_cos2 : unsigned := to_unsigned(natural(65536.0*cos(2.0 * c_base)), 17);
  constant w_cos3 : unsigned := to_unsigned(natural(65536.0*cos(3.0 * c_base)), 17);
  constant w_cos4 : unsigned := to_unsigned(natural(65536.0*cos(4.0 * c_base)), 17);
  constant w_cos5 : unsigned := to_unsigned(natural(65536.0*cos(5.0 * c_base)), 17);
  constant w_cos6 : unsigned := to_unsigned(natural(65536.0*cos(6.0 * c_base)), 17);
  constant w_cos7 : unsigned := to_unsigned(natural(65536.0*cos(7.0 * c_base)), 17);

  -- Flux Mul k-corrected omega LUT
  constant kcon   : real := 0.2239282404699562528386872156786372562;
  constant kw_lut : b25_real_array(0 to 7) := (
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(0.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(1.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(2.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(3.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(4.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(5.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(6.0 * c_base) * kcon)), 24)),
    '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(7.0 * c_base) * kcon)), 24))
  );

  -- Pi constants for angle normalization
  constant pi24            : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**16)*MATH_PI)    ,24));
  constant two_pi24        : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**17)*MATH_PI)    ,24));
  constant half_pi24       : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**15)*MATH_PI)    ,24));
  constant three_half_pi24 : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**15)*3.0*MATH_PI),24));

  -- CORDIC arctangent LUT
  type t_arctan_lut is array (0 to 24) of std_logic_vector(23 downto 0);
  constant arctan_lut : t_arctan_lut := (
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -0.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -1.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -2.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -3.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -4.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -5.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -6.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -7.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -8.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -9.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-10.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-11.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-12.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-13.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-14.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-15.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-16.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-17.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-18.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-19.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-20.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-21.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-22.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-23.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-24.0)))), 24))
  );



  -- Component declarations

  component b25_cmul is
    generic (
      con : std_logic_vector(24 downto 0)
    );
    port (
      a   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_wmul is
    generic (
      w, n : natural
    );
    port (
      i : in    b25_complex;
      o : out   b25_complex
    );
  end component b25_wmul;

  component b25_mul is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_butterfly is
    port (
      i_top, i_bot : in    b25_complex;
      o_top, o_bot : out   b25_complex
    );
  end component b25_butterfly;

  component varshiftright is
    generic (
      len : natural := 8
    );
    port (
      data     : in    std_logic_vector(len - 1 downto 0);
      distance : in    std_logic_vector(integer(ceil(log2(real(len)))) - 1 downto 0);
      result   : out   std_logic_vector(len - 1 downto 0)
    );
  end component;

  component dft is
    port (
      i       : in    b25_real_array(0 to 7);
      o       : out   b25_complex_array(0 to 16);
      clock   : in    std_logic;
      start   : in    std_logic;
      reset   : in    std_logic;
      s_ready : out   std_logic
    );
  end component;

  component fft is
    generic (
      nx, ny, nz : natural range 0 to 16 := 2;
      n_points   : natural range 0 to 1024 := 32
    );
    port (
      i                   : in  b25_3d_real_array(0 to nx-1)(0 to ny-1)(0 to nz-1);
      o                   : out b25_complex_array(0 to n_points/2);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic := '0'
    );
  end component fft;

  component adder_carry is
    port (
      a   : in    std_logic_vector(49 downto 0);
      b   : in    std_logic_vector(49 downto 0);
      cin : in    std_logic;
      o   : out   std_logic_vector(49 downto 0)
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

  component flux_inverter is
    port (
      clock    : in    std_logic;
      reset_s  : in    std_logic;
      reset_as : in    std_logic;
      load     : in    std_logic;
      inp      : in    std_logic_vector(23 downto 0);
      nex      : in    std_logic_vector(23 downto 0);
      outp     : out   std_logic_vector(23 downto 0);
      new_bit  : out   std_logic;
      ready    : out   std_logic;
      erro     : out   std_logic
    );
  end component;

  component flux_multiplier is
    generic (
      n_idx     : natural range 0 to 16 := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      run       : in    std_logic;
      run_coefs : in    std_logic;
      a         : in    std_logic_vector(24 downto 0);
      b         : in    std_logic_vector(24 downto 0);
      a_nex     : in    std_logic_vector(24 downto 0);
      b_nex     : in    std_logic_vector(24 downto 0);
      coefs_x   : out   b25_real_array(0 to 7);
      coefs_y   : out   b25_real_array(0 to 7);
      p         : out   std_logic_vector(24 downto 0);
      ready     : out   std_logic
    );
  end component;

  component hadamard_uc is
    port (
      clock, start, reset    : in     std_logic;
      j_end, mul_ready       : in     std_logic;
      cordic_mode, flux_mode : out    std_logic_vector(1 downto 0);
      rotation               : out    std_logic;
      ready                  : buffer std_logic
    );
  end component;

  component hadamard is
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
  end component;

  component hecate is
    port (
      img, ker            : in b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
      clock, reset, start : in std_logic;
      res                 : out b25_real_array(0 to 26) := (others => (others => '0'));
      o_ready             : out std_logic
    );
  end component;

  component conv3d is
    port (
      img : in  b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
      ker : in  b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
      clk : in  std_logic;
      rst : in  std_logic;
      run : in  std_logic;
      res : out b25_real_array(0 to 26);
      rdy : out std_logic
    );
  end component conv3d;

end package hecate_pkg;

