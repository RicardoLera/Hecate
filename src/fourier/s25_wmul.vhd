  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity t_signed_wmul is
  generic (
    w : natural
  );
  port (
    i : in  t_signed_complex;
    o : out t_signed_complex
  );
end entity t_signed_wmul;

architecture karatsuba of t_signed_wmul is -- 3 constant multipliers + 3 adders
  signal s1, k1, k2, k3, re, im : t_signed;
  constant s2 : t_signed := twiddle_lut(w)(0) + twiddle_lut(w)(1); -- c+d
  constant s3 : t_signed := twiddle_lut(w)(1) - twiddle_lut(w)(0); -- d-c
begin
  s1 <= i(0) + i(1); -- a+b
  k1 <= resize((twiddle_lut(w)(0) * s1) sra signed_point, signed_size); -- c*(a+b)
  k2 <= resize((i(1)              * s2) sra signed_point, signed_size); -- b*(c+d)
  k3 <= resize((i(0)              * s3) sra signed_point, signed_size); -- a*(d-c)
  re <= k1 - k2;
  im <= k1 + k3;
  o <= (re, im);
end architecture karatsuba;
