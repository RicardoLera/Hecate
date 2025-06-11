  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity cordic is
  port (
    j                   : in  integer range 0 to signed_size;
    sigma_in, rotation  : in  std_logic;
    x_in, y_in          : in  t_signed;
    z_in                : in  t_pfb;
    sigma_out, comp_out : out std_logic;
    x_out, y_out        : out t_signed;
    z_out               : out t_pfb
  );
end entity cordic;

architecture synth of cordic is 
  signal shifted_x, shifted_y : t_signed;
  signal x_add,     y_add     : t_signed;
  signal z_add                : t_pfb := (others => '0');
begin

  x_out <= x_in + y_add;
  y_out <= y_in + x_add;
  z_out <= z_in + z_add;

  shifted_x <= x_in sra j when (nand(x_in)) else (others => '0'); -- else allows returning 0
  shifted_y <= y_in sra j when (nand(y_in)) else (others => '0');
    -- when not data(signed_size-1) else (data sra to_integer(distance)) + 1;   -- speeds up timing

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

  comp_out <= '1' when
    (x_in(x_in'left-1 downto 1) = x_out(x_in'left-1 downto 1)) and
    (z_in(z_in'left-1 downto 1) = z_out(z_in'left-1 downto 1)) and
    (j /= 0)
  else '0';
  -- returns 1 if every input is equal to output

end architecture synth;

-- Hardware report:
-- 2x signed_size adder           2*s(+)
-- 1x pbf_size adder                p(+)
-- 2x signed_size variable sra    2*s(v>>)
-- 2x signed_size:1 MUX         2*s:1(MUX)
-- 1x pbf_size:1 MUX              p:1(MUX)
-- 1x 1:1 MUX                     1:1(MUX)

-- Extra (not standard / might change)
-- shift zero MUX and NAND
-- comp_out comparisons
