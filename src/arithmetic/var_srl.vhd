  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity var_srl is -- variable logical shift right
  generic (
    len : natural := 8
  );
  port (
    data     : in    std_logic_vector(len-1 downto 0);
    distance : in    unsigned(cordic_len_log-1 downto 0);
    result   : out   std_logic_vector(len-1 downto 0)
  );
end entity var_srl;

architecture synth of var_srl is begin

  result <= data(len - 1) & std_logic_vector(shift_right(unsigned(data(len - 2 downto 0)), to_integer(unsigned(distance))));
  
end architecture synth;
