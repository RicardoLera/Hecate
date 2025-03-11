library ieee;
  use ieee.std_logic_1164.all;
  use std.env.stop;

entity debug_tb is
end entity debug_tb;

architecture sim of debug_tb is

  component debug is
    generic (
      n_points   : natural range 0 to 1024 := 32
    );
    port (
      clock   : in  std_logic
    );
  end component debug;

  signal   clock, simulate : std_logic := '0';
  constant clockperiod : time := 1 ms; -- 1khz

begin

  clock <= (not clock) and simulate after clockperiod / 2;

  dut : component debug
    generic map (2)
    port map (
      clock => clock
    );

  test : process is
  begin
    simulate <= '1';
    
    wait for 5 ms ;

    simulate <= '0';
    stop;
  end process test;

end architecture sim;