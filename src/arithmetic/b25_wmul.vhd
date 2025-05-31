  use work.hecate_pkg.all;
  use work.function_rom.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_wmul is
  generic (
    w : natural
  );
  port (
    i : in  b25_complex;
    o : out b25_complex
  );
end entity b25_wmul;

architecture karatsuba of b25_wmul is -- 3 constant multipliers + 3 adders
  signal s1, k1, k2, k3, re, im : std_logic_vector(24 downto 0);
begin

  add_s1 : component b25_add
    port map (
      a   => i(0),
      b   => i(1),
      res => s1 -- a+b
    );

  cmul_k1 : component b25_kmul
    generic map (
      con => twiddle_lut(w)(0)
    )
    port map (
      a   => s1,
      res => k1 -- c*(a+b)
    );
  
  cmul_k2 : component b25_kmul
    generic map (
      con => w_add_lut(w)(0) -- s2 = c+d
    )
    port map (
      a   => i(1),
      res => k2 -- b*(c+d)
    );

  cmul_k3 : component b25_kmul
    generic map (
      con => w_add_lut(w)(1) -- s3 = d-c
    )
    port map (
      a   => i(0),
      res => k3 -- a*(d-c)
    );

  add_re : component b25_add
    port map (
      a   => k1,
      b   => (not k2(24), k2(23 downto 0)),
      res => re -- k1-k2
    );
  
  add_im : component b25_add
    port map (
      a   => k1,
      b   => k3,
      res => im -- k1+k3
    );

  o <= (re, im);

end architecture karatsuba;
