  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity b25_wmul is
  generic (
    w : natural
  );
  port (
    i : in    b25_complex;
    o : out   b25_complex
  );
end entity b25_wmul;


architecture karatsuba of b25_wmul is -- 3 constant multipliers + 3 adders

  constant wn : b25_complex := twiddle(w);
  signal   s1, k1, k2, k3, re, im : std_logic_vector(24 downto 0);
  constant s2 : std_logic_vector(24 downto 0) := w_add(wn(0), wn(1)); -- c+d
  constant s3 : std_logic_vector(24 downto 0) := w_add(wn(1), (not wn(0)(24), wn(0)(23 downto 0))); -- d-c

begin

  add_s1 : component b25_add
    port map (
      a   => i(0),
      b   => i(1),
      res => s1 -- a+b
    );

  cmul_k1 : component b25_cmul
    generic map (
      con => wn(0)
    )
    port map (
      a   => s1,
      res => k1 -- c*(a+b)
    );
  
  cmul_k2 : component b25_cmul
    generic map (
      con => s2
    )
    port map (
      a   => i(1),
      res => k2 -- b*(c+d)
    );

  cmul_k3 : component b25_cmul
    generic map (
      con => s3
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
