  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity s25_wmul is
  generic (
    w : natural
  );
  port (
    i : in  s25_complex;
    o : out s25_complex
  );
end entity s25_wmul;

architecture karatsuba of s25_wmul is -- 3 constant multipliers + 3 adders
  signal s1, k1, k2, k3, re, im : s25;
begin
  s1 <= i(0) + i(1); -- a+b
  k1 <= resize((s1   * twiddle_lut(w)(0)) sra 16, 25); -- c*(a+b)
  k2 <= resize((i(1) * w_add_lut(w)(0))   sra 16, 25); -- b*(c+d)
  k3 <= resize((i(0) * w_add_lut(w)(1))   sra 16, 25); -- a*(d-c)
  re <= k1 - k2;
  im <= k1 + k3;
  o <= (re, im);
end architecture karatsuba;
