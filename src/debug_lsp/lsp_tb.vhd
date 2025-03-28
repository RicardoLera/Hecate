library ieee;
  use ieee.std_logic_1164.all;
  use std.env.stop;

entity lsp_tb is
end entity lsp_tb;

architecture sim of lsp_tb is

  component lsp is
    generic (
      n_points   : integer range 0 to 1024 := 32
    );
    port (
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component lsp;

  signal   clock, reset, start, s_ready, simulate : std_logic := '0';
  constant clockperiod : time := 1 us;

begin

  clock <= (not clock) and simulate after clockperiod / 2;

  dut : component lsp
    generic map (32)
    port map (
      clock => clock,
      reset => reset,
      start => start,
      s_ready => s_ready
    );

  test : process is
  begin
    simulate <= '1';
    reset <= '1';

    wait for 1 us;

    reset <= '0';
    start <= '1';

    wait until (s_ready = '1') for 50 us ;

    wait for 1 us;

    start <= '0';
    simulate <= '0';
    stop;
  end process test;

end architecture sim;