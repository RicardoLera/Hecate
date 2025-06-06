  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cordic is
  port (
    sigma_in  : in    std_logic := '0';
    rotation  : in    std_logic;
    j         : in    unsigned(cordic_len_log-1 downto 0);
    x_in      : in    s25;
    y_in      : in    s25;
    z_in      : in    p16;
    x_out     : out   s25;
    y_out     : out   s25;
    z_out     : out   p16;
    sigma_out : out   std_logic
  );
end entity cordic;

architecture synth of cordic is

  signal shifted_x, shifted_y : s25;
  signal x_add,     y_add     : s25;
  signal z_add                : p16 := (others => '0');

begin

  shift_x : component var_sra
    port map (
      data     => x_in,
      distance => j,
      result   => shifted_x
    );

  shift_y : component var_sra
    port map (
      data     => y_in,
      distance => j,
      result   => shifted_y
    );

  x_out <= x_in + y_add;
  y_out <= y_in + x_add;
  z_out <= std_logic_vector(signed(z_in) + signed(z_add));

  with sigma_in select y_add <=
    -shifted_y when '0', -- x-s_y when '0',
    shifted_y when others; -- x+s_y when others;

  with sigma_in select x_add <=
    shifted_x when '0', -- y+s_x when '0'
    -shifted_x when others; -- y-s_x when others;

  z_add <= arctan_lut(0)(to_integer(unsigned(j))) when sigma_in -- z+lut when '1' else z-lut
    else arctan_lut(1)(to_integer(unsigned(j)));

  with rotation select sigma_out <=
    z_out(z_out'length - 1) when '1',
    not y_out(y_out'length - 1) when others;

end architecture synth;
