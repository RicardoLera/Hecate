library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity b25_wmul is
  generic (
    w, n : natural
  );
  port (
    i : in    b25_complex;
    o : out   b25_complex
  );
end entity b25_wmul;


architecture karatsuba of b25_wmul is -- 3 constant multipliers + 3 adders

  -- Generic twiddle function
  function twiddle (inp, pnt : natural) return b25_complex is
    constant base : real := 2.0*MATH_PI/real(pnt);
    variable x : b25_complex;
  begin
    x(0) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*cos(real(inp) * base)), 17)));
    x(1) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*sin(real(inp) * base)), 17)));
    if (inp > pnt/4) then
      x(0)(24) := ('1');
    end if;
    return b25_complex(x);
  end function;
  constant wn : b25_complex := twiddle(w, n);

  signal   s1, k1, k2, k3, re, im : std_logic_vector(24 downto 0);
  constant s2 : std_logic_vector(24 downto 0) := std_logic_vector(unsigned(wn(0)) + unsigned(wn(1))); -- c+d
  constant s3 : std_logic_vector(24 downto 0) := std_logic_vector(unsigned(wn(1)) - unsigned(wn(0))); -- d-c

begin

  add_s1 : component b25_add
    port map (
      a   => i(0),
      b   => i(1),
      res => s1 -- a+b
    );

  cmul_k1 : component b25_cmul
    generic map (
      con => twiddle(w,n)(0)
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
