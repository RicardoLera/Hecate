  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cordic is
  port (
    j                  : in  integer range 0 to cordic_len;
    sigma_in, rotation : in  std_logic;
    sigma_out          : out std_logic;
    x_in, y_in         : in  t_signed;
    x_out, y_out       : out t_signed;
    z_in               : in  t_pfb;
    z_out              : out t_pfb
  );
end entity cordic;

architecture synth of cordic is
  signal shifted_x, shifted_y : t_signed;
  signal x_add,     y_add     : t_signed;
  signal z_add                : t_pfb := (others => '0');
begin

  shifted_x <= x_in sra j;
  shifted_y <= y_in sra j;
    -- when not data(signed_size-1) else (data sra to_integer(distance)) + 1;   -- speeds up timing
    -- when distance /= cordic_len-1 else (others => '0') ;          -- allows returning 0 for negative values

  x_out <= x_in + y_add;
  y_out <= y_in + x_add;
  z_out <= z_in + z_add;

  with sigma_in select y_add <=
    -shifted_y when '0',    -- x-s_y when '0',
    shifted_y  when others; -- x+s_y when others;

  with sigma_in select x_add <=
    shifted_x  when '0',    -- y+s_x when '0'
    -shifted_x when others; -- y-s_x when others;

  z_add <= cordic_lut(0)(j) when sigma_in -- z+lut when '1' else z-lut
    else cordic_lut(1)(j);

  with rotation select sigma_out <=
    z_out(z_out'length - 1) when '1',
    not y_out(y_out'length - 1) when others;

end architecture synth;
