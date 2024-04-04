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

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  signal shifted_x, shifted_y : std_logic_vector(coords_len - 1 downto 0);
  signal x_add,     y_add     : std_logic_vector(coords_len - 1 downto 0);
  signal z_add                : std_logic_vector(z_len - 1 downto 0) := (others => '0');

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

  shift_x : component varshiftright
    generic map (
      len => coords_len
    )
    port map (
      data     => x_in,
      distance => j,
      result   => shifted_x
    );

  shift_y : component varshiftright
    generic map (
      len => coords_len
    )
    port map (
      data     => y_in,
      distance => j,
      result   => shifted_y
    );

  xadd : component b25_add
    port map (
      a   => x_in,
      b   => y_add,
      res => x_out
    );

  yadd : component b25_add
    port map (
      a   => y_in,
      b   => x_add,
      res => y_out
    );

  -- zadd : b25_add port map(
  --   a => z_in,
  --   b => z_add,
  --   res => z_out
  -- );

  with sigma_in select z_out <=
    std_logic_vector(signed(z_in) - signed(z_add)) when '0',    -- z-lut when '0'
    std_logic_vector(signed(z_in) + signed(z_add)) when others; -- z+lut when others;

  with sigma_in select y_add <=
    not shifted_y(coords_len - 1) & shifted_y(coords_len - 2 downto 0) when '0', -- x-s_y when '0',
    shifted_y(coords_len - 1) & shifted_y(coords_len - 2 downto 0) when others;  -- x+s_y when others;

  with sigma_in select x_add <=
    not shifted_x(coords_len - 1) & shifted_x(coords_len - 2 downto 0) when '0', -- y+s_x when '0'
    shifted_x(coords_len - 1) & shifted_x(coords_len - 2 downto 0) when others;  -- y-s_x when others;

  z_add <=
  (
    33 downto 0 => lut(to_integer(unsigned(j))),
    others      => '0'
  );

  with rotation select sigma_out <=
    z_out(z_len - 1) when '1',
    NOT y_out(y_out'length - 1) when others;

end architecture arch;
