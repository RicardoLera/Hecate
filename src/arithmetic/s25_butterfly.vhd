  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity s25_butterfly is
  port (
    i_top, i_bot : in  s25_complex;
    o_top, o_bot : out s25_complex
  );
end entity s25_butterfly;

architecture synth of s25_butterfly is begin
  o_top(0) <= i_top(0) + i_bot(0);
  o_top(1) <= i_top(1) + i_bot(1);
  o_bot(0) <= i_top(0) - i_bot(0);
  o_bot(1) <= i_top(1) - i_bot(1);
end architecture synth;
