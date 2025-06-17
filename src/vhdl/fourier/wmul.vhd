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

architecture karatsuba of wmul is
  signal a, b, c, s1, s2, s3, k1, k2, k3, re, im : t_signed;
  signal s_n : natural;
begin
  s_n <= 1 when s else 0;

  a <= i(0);
  b <= i(1);
  c <= twiddle_lut(w)(s_n)(0);

  s1 <= a + b;                      -- signed_size adder
  s2 <= twiddle_add_lut(w)(s_n)(0); -- c+d (constant)
  s3 <= twiddle_add_lut(w)(s_n)(1); -- d-c (constant)

  k1 <= resize((c * s1) sra signed_point, signed_size); -- constant(c) multiplier
  k2 <= resize((b * s2) sra signed_point, signed_size); -- constant(c+d) multiplier
  k3 <= resize((a * s3) sra signed_point, signed_size); -- constant(d-c) multiplier

  -- casts to define DST length [too much precision loss]
  -- k1 <= c(signed_size/2+signed_point/2-1 downto signed_point/2) * s1(signed_size/2+signed_point/2-1 downto signed_point/2); -- c*(a+b)
  -- k2 <= b(signed_size/2+signed_point/2-1 downto signed_point/2) * s2(signed_size/2+signed_point/2-1 downto signed_point/2); -- b*(c+d)
  -- k3 <= a(signed_size/2+signed_point/2-1 downto signed_point/2) * s3(signed_size/2+signed_point/2-1 downto signed_point/2); -- a*(d-c)

  re <= k1 - k2; -- signed_size adder
  im <= k1 + k3; -- signed_size adder

  o <= (re, im);

  -- Total hardware: 3 constant multipliers + 3 signed_size adders
  -- 
  -- PATHING:
  -- [signed_size adder](s1=a+b) -> [constant multiplier](k1=c*s1)        -> [signed_size adder](k1-k2)
  -- [read twiddle LUT](c)-------/\                                     /\ ||
  --                                                                    || ||
  -- [read twiddle_add LUT](s2=c+d) -> [constant multiplier](k2=b*s2) --|| ||
  --                                                                       \/
  -- [read twiddle_add LUT](s3=d-c) -> [constant multiplier](k3=a*s3) ------> [signed_size adder](k1+k3)
  -- 
  -- CRITICAL PATH: ([signed_size adder] | [read LUT]) -> [constant multiplier] -> [signed_size adder]
end architecture karatsuba;

architecture cmul of wmul is
  signal a, b, c, d, re, im : t_signed;
  signal s_n : natural;
begin
  s_n <= 1 when s else 0;

  a <= i(0);
  b <= i(1);
  c <= twiddle_lut(w)(s_n)(0);
  d <= twiddle_lut(w)(s_n)(1);

  re <= resize((a*c - d*b) sra signed_point, signed_size);
  im <= resize((a*d + b*c) sra signed_point, signed_size);

  o <= (re, im);

  -- (a+bi)*(c+di) = (ac - db) + (ad + bc)i
  -- 
  -- Total hardware: 4 constant multipliers + 2 signed_size adders
  -- 
  -- CRITICAL PATH: [read LUT] -> [constant multiplier] -> [signed_size adder]
end architecture cmul;


  -- Assuming [signed_size adder] > [read LUT], standard complex mul is a bit faster
  -- Hardware efficiency gain (karatsuba) = ([constant multiplier]-[signed_size adder])[hardware] / ([signed_size adder]-[read LUT])[speed]