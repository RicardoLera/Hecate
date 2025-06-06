  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cordic is
  port (
    sigma_in  : in    std_logic := '0';
    rotation  : in    std_logic;
    j         : in    unsigned(cordic_len_log-1 downto 0);
    x_in      : in    b25;
    y_in      : in    b25;
    z_in      : in    p16;
    x_out     : out   b25;
    y_out     : out   b25;
    z_out     : out   p16;
    sigma_out : out   std_logic
  );
end entity cordic;

architecture synth of cordic is

  signal shifted_x, shifted_y : std_logic_vector(25 - 1 downto 0);
  signal x_add,     y_add     : std_logic_vector(25 - 1 downto 0);
  signal z_add                : std_logic_vector(16 - 1 downto 0) := (others => '0');

begin

  shift_x : component var_srl
    port map (
      data     => x_in,
      distance => j,
      result   => shifted_x
    );

  shift_y : component var_srl
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

  z_out <= std_logic_vector(signed(z_in) + signed(z_add));

  with sigma_in select y_add <=
    not shifted_y(25 - 1) & shifted_y(25 - 2 downto 0) when '0', -- x-s_y when '0',
    shifted_y(25 - 1) & shifted_y(25 - 2 downto 0) when others;  -- x+s_y when others;

  with sigma_in select x_add <=
    shifted_x(25 - 1) & shifted_x(25 - 2 downto 0) when '0',        -- y+s_x when '0'
    not shifted_x(25 - 1) & shifted_x(25 - 2 downto 0) when others; -- y-s_x when others;

  with sigma_in select z_add <=
    std_logic_vector(-signed(arctan_lut(to_integer(unsigned(j))))) when '0',   -- z-lut when '0'
    std_logic_vector(signed(arctan_lut(to_integer(unsigned(j))))) when others; -- z+lut when others;

  with rotation select sigma_out <=
    z_out(z_out'length - 1) when '1',
    not y_out(y_out'length - 1) when others;

end architecture synth;
