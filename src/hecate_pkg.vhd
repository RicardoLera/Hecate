library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

  -- 25-bit variables
  type b25_real_array is array (natural range <>) of std_logic_vector(24 downto 0);  -- later make these into records
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  type b25_complex_array is array (natural range <>) of b25_complex;

  -- 3d padding
  type padding is array(0 to 7) of natural range 0 to 32;
  constant pad3d : padding := (0, 1, 3, 4, 9, 10, 12, 13);

  -- DFT multiplication coeficient array
  type t_calc_vals_arr is array(0 to 31) of b25_real_array(0 to 7);

  -- DFT rotation reference
  type t_cos_val_ref is array(0 to 31) of natural range 0 to 8;
  type t_cos_sig_ref is array(0 to 31) of boolean;  
  constant cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1); -- Assuming no DFT-IDFT inversion
  constant cos_sig_ref : t_cos_sig_ref := (false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, false, false, false, false);
  
  -- DFT omega constants
  constant c_base : real := MATH_PI/16.0;
  constant w_cos1 : unsigned := to_unsigned(natural(65536.0*cos(1.0 * c_base)), 17);
  constant w_cos2 : unsigned := to_unsigned(natural(65536.0*cos(2.0 * c_base)), 17);
  constant w_cos3 : unsigned := to_unsigned(natural(65536.0*cos(3.0 * c_base)), 17);
  constant w_cos4 : unsigned := to_unsigned(natural(65536.0*cos(4.0 * c_base)), 17);
  constant w_cos5 : unsigned := to_unsigned(natural(65536.0*cos(5.0 * c_base)), 17);
  constant w_cos6 : unsigned := to_unsigned(natural(65536.0*cos(6.0 * c_base)), 17);
  constant w_cos7 : unsigned := to_unsigned(natural(65536.0*cos(7.0 * c_base)), 17);

  -- Hadamard coeficient array generic type
  type t_coefs_arr is array(0 to 7) of b25_real_array;

  -- Flux Mul omega LUT
  constant kcon   : real := 0.2239282404699562528386872156786372562;
  constant kw_lut : t_coefs_arr := (
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(0.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(1.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(2.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(3.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(4.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(5.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(6.0 * c_base) * kcon)), 17)),
    "00000000" & std_logic_vector(to_unsigned(natural(65536.0*(cos(7.0 * c_base) * kcon)), 17))
  );

  --"0000000000001010111101111000000000001010001000100000000000000110100111101100000000000011100101010011";    -- Make generic
  -- lut(24 downto 0)  <= "0000000000011100101010011"; -- kcon = 1 / k^3    0x3953
  -- lut(49 downto 25) <= "0000000000011010011110110"; -- 0x34f6
  -- lut(74 downto 50) <= "0000000000010100010001000"; -- 0x2888
  -- lut(99 downto 75) <= "0000000000001010111101111"; -- 0x15ef

  -- CORDIC arctangent LUT
  type t_arctan_lut is array (0 to 31) of std_logic_vector(23 downto 0); -- Fix later, doesn't need 31
  constant arctan_lut : t_arctan_lut := (
    24x"c910",
    24x"76b2",
    24x"3eb7",
    24x"1fd6",

    24x"0ffb",
    24x"07ff",
    24x"0400",
    24x"0200",

    24x"0100",
    24x"0080",
    24x"0040",
    24x"0020",

    24x"0010",
    24x"0008",
    24x"0004",
    24x"0002",

    24x"0001",
    24x"0000",
    24x"0000",
    24x"0000",

    24x"0000",
    24x"0000",
    24x"0000",
    24x"0000",

    24x"0000",
    24x"0000",
    24x"0000",
    24x"0000",

    24x"0000",
    24x"0000",
    24x"0000",
    24x"0000"
  );

  -- Component declarations

  component b25_cmul is
    port (
      a   : in    std_logic_vector(24 downto 0);
      con : in    std_logic_vector(24 downto 0);
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

  component varshiftright is
    generic (
      len : natural := 8
    );
    port (
      data     : in    std_logic_vector(len - 1 downto 0);
      distance : in    std_logic_vector(INTEGER(ceil(log2(real(len)))) - 1 downto 0);
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

  component flux_multiplier is
    generic (
      size      : natural              := 25;
      frac_size : natural              := 16;
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
      coefs_x : out   std_logic_vector(((7 + 1) * size) - 1 downto 0);
      coefs_y : out   std_logic_vector(((7 + 1) * size) - 1 downto 0);
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

  component hadamard is
    generic (
      n_idx : natural range 0 to 7 := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      start     : in    std_logic;
      x_i       : in    std_logic_vector(24 downto 0);
      y_i       : in    std_logic_vector(24 downto 0);
      x_k       : in    std_logic_vector(24 downto 0);
      y_k       : in    std_logic_vector(24 downto 0);
      p_coefs_x : out   std_logic_vector(((7 + 1) * 25) - 1 downto 0);
      p_coefs_y : out   std_logic_vector(((7 + 1) * 25) - 1 downto 0);
      ready     : buffer std_logic
    );
  end component;
end package hecate_pkg;

