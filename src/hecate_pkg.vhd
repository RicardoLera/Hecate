library ieee;
  use ieee.std_logic_1164.all;

package hecate_pkg is

  type b25_real_array is array (natural range <>) of std_logic_vector(24 downto 0);  -- later make these into records

  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);

  type b25_complex_array is array (natural range <>) of b25_complex;

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

  component flux_multiplier is
    generic (
      size      : natural              := 25;
      frac_size : natural              := 16;
      logn      : natural range 1 to 3 := 3;
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
      logn  : natural range 1 to 3 := 3;
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
      p_coefs_x : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
      p_coefs_y : out   std_logic_vector(((logn + 1) * 25) - 1 downto 0);
      ready     : buffer std_logic
    );
  end component;
end package hecate_pkg;

