library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity cordic is
  generic (
    z_len      : natural := 36;
    z_lut_len  : natural := 34;
    j_len      : natural := 5;
    coords_len : natural := 25
  );

  -- 36, 34, 5, 25
  port (
    sigma_in  : in    std_logic;
    rotation  : in    std_logic;
    j         : in    std_logic_vector(j_len - 1 downto 0);
    x_in      : in    std_logic_vector(coords_len - 1 downto 0);
    y_in      : in    std_logic_vector(coords_len - 1 downto 0);
    z_in      : in    std_logic_vector(z_len - 1 downto 0);
    x_out     : out   std_logic_vector(coords_len - 1 downto 0);
    y_out     : out   std_logic_vector(coords_len - 1 downto 0);
    z_out     : out   std_logic_vector(z_len - 1 downto 0);
    sigma_out : out   std_logic
  );
end entity cordic;

architecture arch of cordic is

  -- IP for board optimization

  -- COMPONENT ip_rightshift IS
  --   PORT (
  --     data : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
  --     distance : IN STD_LOGIC_VECTOR (4 DOWNTO 0);
  --     result : OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
  --   );
  -- END COMPONENT;
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

  component comp_sign_conv is
    generic (
      size : natural := 32
    );
    port (
      comp_in : in    std_logic_vector(size - 1 downto 0);
      mag_out : out   std_logic_vector(size - 1 downto 0);
      s       : out   std_logic
    );
  end component;

  component sign_comp_conv is
    generic (
      size : natural := 32
    );
    port (
      mag_in : in    std_logic_vector(size - 1 downto 0);
      s      : in    std_logic;
      comp   : out   std_logic_vector(size - 1 downto 0)
    );
  end component;

  signal shifted_x          : std_logic_vector(coords_len - 1 downto 0);
  signal shifted_y          : std_logic_vector(coords_len - 1 downto 0);
  signal s_y_out            : std_logic_vector(coords_len - 1 downto 0);
  signal s_z_out, z_lut     : std_logic_vector(z_len - 1 downto 0);
  signal x_in_mag           : std_logic_vector(coords_len - 1 downto 0);
  signal y_in_mag           : std_logic_vector(coords_len - 1 downto 0);
  signal shifted_x_mag      : std_logic_vector(coords_len - 1 downto 0);
  signal shifted_y_mag      : std_logic_vector(coords_len - 1 downto 0);
  signal long_x_in_mag      : std_logic_vector(31 downto 0);
  signal long_y_in_mag      : std_logic_vector(31 downto 0);
  signal long_shifted_x_mag : std_logic_vector(31 downto 0);
  signal long_shifted_y_mag : std_logic_vector(31 downto 0);
  signal x_in_sign          : std_logic;
  signal y_in_sign          : std_logic;
  signal x_sign_flipped     : std_logic;
  signal y_sign_flipped     : std_logic;

  type lut_type is ARRAY (0 to 31) OF std_logic_vector(33 downto 0);

  constant lut : lut_type :=
  (
    "1000000000000000000000000000000000",
    "0100101110010000000101000111011001",
    "0010011111101100111000010110110101",
    "0001010001000100010001110101000001",
    "0000101000101100001101010000110000",
    "0000010100010111010111111000010101",
    "0000001010001011110110000111100101",
    "0000000101000101111100010101010001",
    "0000000010100010111110010100110100",
    "0000000001010001011111001011101011",
    "0000000000101000101111100110000000",
    "0000000000010100010111110011000001",
    "0000000000001010001011111001100000",
    "0000000000000101000101111100110000",
    "0000000000000010100010111110011000",
    "0000000000000001010001011111001100",
    "0000000000000000101000101111100110",
    "0000000000000000010100010111110011",
    "0000000000000000001010001011111001",
    "0000000000000000000101000101111100",
    "0000000000000000000010100010111110",
    "0000000000000000000001010001011111",
    "0000000000000000000000101000101111",
    "0000000000000000000000010100010111",
    "0000000000000000000000001010001011",
    "0000000000000000000000000101000101",
    "0000000000000000000000000010100010",
    "0000000000000000000000000001010001",
    "0000000000000000000000000000101000",
    "0000000000000000000000000000010100",
    "0000000000000000000000000000001010",
    "0000000000000000000000000000000101"
  );

begin

  -- x treatment

  magsign_x : component comp_sign_conv
    generic map (
coords_len
    )
    port map (
x_in,
 x_in_mag,
 x_in_sign
    );

  x_sign_flipped <= x_in_sign xor (sigma_in);
  --  shift_x : shiftright PORT MAP(x_in_mag, j, shifted_x_mag);
  shift_x : component varshiftright
    generic map (
coords_len
    )
    port map (
x_in_mag,
 j,
 shifted_x_mag
    );

  -- shift_x_ip : ip_rightshift PORT MAP(long_x_in_mag, j, long_shifted_x_mag);
  long_x_in_mag <= "0000000" & x_in_mag;
  shifted_x_mag <= long_shifted_x_mag(coords_len - 1 downto 0);

  signmag_x : component sign_comp_conv
    generic map (
coords_len
    )
    port map (
shifted_x_mag,
 x_sign_flipped,
 shifted_x
    );

  -- y treatment

  magsign_y : component comp_sign_conv
    generic map (
coords_len
    )
    port map (
y_in,
 y_in_mag,
 y_in_sign
    );

  y_sign_flipped <= y_in_sign xor (NOT sigma_in);
  --  shift_y : shiftright PORT MAP(y_in_mag, j, shifted_y_mag);
  shift_y : component varshiftright
    generic map (
coords_len
    )
    port map (
y_in_mag,
 j,
 shifted_y_mag
    );

  -- shift_y_ip : ip_rightshift PORT MAP(long_y_in_mag, j, long_shifted_y_mag);
  long_y_in_mag <= "0000000" & y_in_mag;
  shifted_y_mag <= long_shifted_y_mag(coords_len - 1 downto 0);

  signmag_y : component sign_comp_conv
    generic map (
coords_len
    )
    port map (
shifted_y_mag,
 y_sign_flipped,
 shifted_y
    );

  with rotation select sigma_out <=
    s_z_out(z_len - 1) when '1',
    NOT s_y_out(s_y_out'length - 1) when OTHERS;

  --  WITH sigma_in SELECT
  --  x_out <= STD_LOGIC_VECTOR(signed(x_in) - signed(shifted_y)) WHEN '0',
  --  STD_LOGIC_VECTOR(signed(x_in) + signed(shifted_y)) WHEN OTHERS;
  --
  --  WITH sigma_in SELECT
  --  s_y_out <= STD_LOGIC_VECTOR(signed(y_in) + signed(shifted_x)) WHEN '0',
  --  STD_LOGIC_VECTOR(signed(y_in) - signed(shifted_x)) WHEN OTHERS;

  x_out   <= std_logic_vector(signed(x_in) + signed(shifted_y));
  s_y_out <= std_logic_vector(signed(y_in) + signed(shifted_x));

  y_out                             <= s_y_out;
  z_lut(z_lut_len - 1 DOWNTO 0)     <= lut(to_integer(unsigned(j)))(33 downto 34 - z_lut_len);
  z_lut(z_len - 1 DOWNTO z_lut_len) <= (OTHERS => '0');

  with sigma_in select s_z_out <=
    std_logic_vector(signed(z_in) - signed(z_lut)) when '0',
    std_logic_vector(signed(z_in) + signed(z_lut)) when OTHERS;
  z_out <= s_z_out;

end architecture arch;
