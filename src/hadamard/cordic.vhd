  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cordic is
  generic (
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
    z_in      : in    std_logic_vector(coords_len - 1 downto 0);
    x_out     : out   std_logic_vector(coords_len - 1 downto 0);
    y_out     : out   std_logic_vector(coords_len - 1 downto 0);
    z_out     : out   std_logic_vector(coords_len - 1 downto 0);
    sigma_out : out   std_logic
  );
end entity cordic;

architecture synth of cordic is

  signal shifted_x, shifted_y : std_logic_vector(coords_len - 1 downto 0);
  signal x_add,     y_add     : std_logic_vector(coords_len - 1 downto 0);
  signal z_add                : std_logic_vector(coords_len - 1 downto 0) := (others => '0');

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

  zadd : component b25_add
    port map (
      a   => z_in,
      b   => z_add,
      res => z_out
    );

  with sigma_in select y_add <=
    not shifted_y(coords_len - 1) & shifted_y(coords_len - 2 downto 0) when '0', -- x-s_y when '0',
    shifted_y(coords_len - 1) & shifted_y(coords_len - 2 downto 0) when others;  -- x+s_y when others;

  with sigma_in select x_add <=
    shifted_x(coords_len - 1) & shifted_x(coords_len - 2 downto 0) when '0',        -- y+s_x when '0'
    not shifted_x(coords_len - 1) & shifted_x(coords_len - 2 downto 0) when others; -- y-s_x when others;

  with sigma_in select z_add <=
    '1' & std_logic_vector(arctan_lut(to_integer(unsigned(j)))) when '0',    -- z-lut when '0'
    '0' & std_logic_vector(arctan_lut(to_integer(unsigned(j)))) when others; -- z+lut when others;

  with rotation select sigma_out <=
    z_out(z_out'length - 1) when '1',
    not y_out(y_out'length - 1) when others;

end architecture synth;
