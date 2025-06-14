  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wmul is
  port (
    i : in  t_signed_complex;
    w : in  natural;
    s : in  std_logic;
    o : out t_signed_complex
  );
end entity wmul;

architecture karatsuba of wmul is -- 3 constant multipliers + 3 adders
  signal a, b, c, d, s1, s2, s3, k1, k2, k3, re, im : t_signed;
  signal s_n : natural;
begin
  s_n <= 1 when s else 0;

  a <= i(0);
  b <= i(1);
  c <= twiddle_lut(w)(s_n)(0);
  d <= twiddle_lut(w)(s_n)(1);

  s1 <= a + b;
  s2 <= c + d;
  s3 <= d - c;

  k1 <= resize((c * s1) sra signed_point, signed_size); -- c*(a+b)
  k2 <= resize((b * s2) sra signed_point, signed_size); -- b*(c+d)
  k3 <= resize((a * s3) sra signed_point, signed_size); -- a*(d-c)

  re <= k1 - k2;
  im <= k1 + k3;

  o <= (re, im);
end architecture karatsuba;
