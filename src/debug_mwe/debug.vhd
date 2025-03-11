library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  entity debug is
    generic (
      n_points   : natural range 0 to 64
    );
    port (
      clock : in  std_logic
    );
  end entity debug;

architecture sim of debug is

  -- would records fix this?
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  type b25_complex_array is array (natural range <>) of b25_complex;
  type b25_2d_complex_array is array (natural range <>) of b25_complex_array;

  signal bfly_in : b25_2d_complex_array(0 to n_points/2-1)(0 to 1);

begin

  -- Concurrent Processes
  gen_procs_bfly : for n in 0 to n_points-1 generate

    proc_bfly : process (clock) is
      variable b, tb : integer;
    begin
      if (rising_edge(clock)) then
        report "process trigger";

        b := n/2;
        tb := n mod 2;
        
        report "n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) ;

        bfly_in(b)(tb) <= ("0000000010000000000000000", 25b"0");

        report integer'image(to_integer(unsigned(bfly_in(b)(tb)(0))));

      end if;
      
    end process proc_bfly;
  end generate gen_procs_bfly;

end architecture sim;