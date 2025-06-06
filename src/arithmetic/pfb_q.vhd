  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity pfb_q is
  port (
    a   : in p16;
    qt  : in std_logic_vector(1 downto 0);
    res : out p16
  );
end entity pfb_q;

architecture synth of pfb_q is
  signal qa, q_dif : std_logic_vector(1 downto 0);
  signal mantissa  : std_logic_vector(13 downto 0);
begin
  qa <= (a(15 downto 14));
  q_dif <= std_logic_vector(signed(qt) - signed(qa));

  with q_dif(0) select mantissa <=
    a(13 downto 0) when '0',
    std_logic_vector(-signed(a(13 downto 0))) when others;

  res <= (qt, mantissa);
end architecture synth;