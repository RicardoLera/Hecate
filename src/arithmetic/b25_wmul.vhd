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
    -- report "inp = " & integer'image(inp) & "   pnt/4 = " & integer'image(pnt/4);
    if (inp > pnt/4) then
      x(0) := ('1', "0000000", std_logic_vector(to_unsigned(natural(65536.0*cos(real(pnt/2-inp) * base)), 17)));
    else
      x(0) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*cos(real(inp) * base)), 17)));
    end if;
    x(1) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*sin(real(inp) * base)), 17)));
    return b25_complex(x);
  end function;

  -- b25_add function (synth-time)
  function w_add (a, b : std_logic_vector(24 downto 0)) return std_logic_vector is
    variable temp_res   : std_logic_vector(23 downto 0) := (others => '0');
    variable temp_sign  : std_logic := '0';
    variable sa, sb, st : signed(23 downto 0);
  begin
    sa := signed(a(23 downto 0));
    sb := signed(b(23 downto 0));
    if ((a(24) xor b(24)) = '1') then
      st := sa - sb;
      if (st < 0) then
        temp_res  := std_logic_vector(-st);
        temp_sign := b(24);
      else
        temp_res  := std_logic_vector(st);
        temp_sign := a(24);
      end if;
    else
      temp_res  := std_logic_vector(sa + sb);
      temp_sign := a(24);
    end if;
    return (temp_sign & temp_res);
  end function;

  constant wn : b25_complex := twiddle(w, n);
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

  -- add_s2 : component b25_add
  --   port map (
  --     a   => wn(0),
  --     b   => wn(1),
  --     res => s2 -- c+d
  --   );

  -- add_s3 : component b25_add
  --   port map (
  --     a   => wn(1),
  --     b   => (not wn(0)(24), wn(0)(23 downto 0)),
  --     res => s3 -- d-c
  --   );

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
