  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity pfb_q is
  port (
    a   : in t_pfb;
    qt  : in signed(1 downto 0);
    res : out t_pfb
  );
end entity pfb_q;

architecture synth of pfb_q is
  signal qa, q_dif : signed(1 downto 0);
  signal mantissa  : signed(pfb_size-3 downto 0);
begin
  qa <= a(pfb_size-1 downto pfb_size-2);
  q_dif <= qt - qa;

  with q_dif(0) select mantissa <=
    a(pfb_size-3 downto 0) when '0',
    -a(pfb_size-3 downto 0) when others;

  res(pfb_size-1 downto pfb_size-2) <= "10" when ((a(pfb_size-3 downto 0) = signed_zero(pfb_size-3 downto 0)) and (qt="01")) -- Test 77 edge case
    else qt;

  res(pfb_size-3 downto 0) <= mantissa;
end architecture synth;