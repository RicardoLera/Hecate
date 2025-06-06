  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity var_srl is -- variable logical shift right
  port (
    data     : in    b25;
    distance : in    unsigned(cordic_len_log-1 downto 0);
    result   : out   b25
  );
end entity var_srl;

architecture synth of var_srl is begin

  result <= data(24) & std_logic_vector(shift_right(unsigned(data(23 downto 0)), to_integer(unsigned(distance))));
  
end architecture synth;
