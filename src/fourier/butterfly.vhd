  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity butterfly is
  port (
    i_top, i_bot : in  t_signed_complex;
    o_top, o_bot : out t_signed_complex
  );
end entity butterfly;

architecture synth of butterfly is begin
  o_top(0) <= i_top(0) + i_bot(0);
  o_top(1) <= i_top(1) + i_bot(1);
  o_bot(0) <= i_top(0) - i_bot(0);
  o_bot(1) <= i_top(1) - i_bot(1);
end architecture synth;
