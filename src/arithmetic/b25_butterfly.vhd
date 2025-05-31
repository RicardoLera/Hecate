  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity b25_butterfly is
  port (
    i_top, i_bot : in  b25_complex;
    o_top, o_bot : out b25_complex
  );
end entity b25_butterfly;

architecture synth of b25_butterfly is begin

  add_top1 : component b25_add
    port map (
      a   => i_top(0),
      b   => i_bot(0),
      res => o_top(0)
    );

  add_top2 : component b25_add
    port map (
      a   => i_top(1),
      b   => i_bot(1),
      res => o_top(1)
    );
  
  add_bot1 : component b25_add
    port map (
      a   => i_top(0),
      b   => (not i_bot(0)(24), i_bot(0)(23 downto 0)),
      res => o_bot(0)
    );

  add_bot2 : component b25_add
    port map (
      a   => i_top(1),
      b   => (not i_bot(1)(24), i_bot(1)(23 downto 0)),
      res => o_bot(1)
    );

end architecture synth;
