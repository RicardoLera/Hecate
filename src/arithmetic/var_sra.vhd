  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity var_sra is -- variable arithmetic shift right
  port (
    data     : in    s25;
    distance : in    unsigned(cordic_len_log-1 downto 0);
    result   : out   s25
  );
end entity var_sra;

architecture synth of var_sra is begin

  result <= data sra to_integer(distance)
    when distance /= cordic_len-1 else (others => '0') ; -- allows returning 0 for negative values
  
end architecture synth;
