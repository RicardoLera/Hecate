library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_tb is
end entity hecate_tb;

architecture sim of hecate_tb is

  signal img, ker          : b25_real_array(0 to 7);

  signal clk, reset, start : std_logic := '0';
  signal o_ready           : std_logic;
  signal res               : b25_real_array(0 to 26);

  signal keep_simulating   : std_logic := '0';
  constant clockperiod     : time      := 1 ms;

  signal gold              : b25_real_array(0 to 26);
  signal run_gold, g_ready : std_logic := '0';
  constant test_n          : integer := 20;

  impure function rand_slv(len : integer; s1 : integer; s2 : integer) return std_logic_vector is
    variable r : real;
    variable slv : std_logic_vector(len - 1 downto 0);
    variable seed1 : positive := s1;
    variable seed2 : positive := s2;
  begin
    for i in slv'range loop
      uniform(seed1, seed2, r);
      slv(i) := '1' when r > 0.5 else '0';
    end loop;
    return slv;
  end function;

  procedure rand_arr(signal arr : out b25_real_array(0 to 7); constant offset : in integer) is begin
    rand_loop : for i in 0 to 7 loop
      arr(i)   <= '0' & "00000000" & rand_slv(16, i+1, i+1+offset);
    end loop rand_loop;
  end procedure;

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hecate
    port map (
      img     => img,
      ker     => ker,
      clock   => clk,
      reset   => reset,
      start   => start,
      res     => res,
      o_ready => o_ready
    );

  golden : component conv3d
    port map (
      img     => img,
      ker     => ker,
      run     => run_gold,
      clk     => clk,
      rst     => reset,
      rdy     => g_ready,
      res     => gold
    );

  test : process 
    variable test_res, pnt : integer := 0;
    variable err           : signed(23 downto 0);
  begin
    keep_simulating <= '1';

    test_loop : for n in 0 to test_n-1 loop
      rand_arr(img, n+1);
      rand_arr(ker, n+2);
      
      -- one_loop : for i in 0 to 7 loop
      --   img(i)   <= '0' & "00000001" & "0000000000000000";
      --   ker(i)   <= '0' & "00000001" & "0000000000000000";
      -- end loop one_loop;

        -- img(2)   <= '0' & "00000000" & "1000000000000100";
        -- ker(1)   <= '0' & "00000000" & "1000000000000000";

      wait for 5 * clockperiod;
      reset <= '0'; start <= '1'; run_gold <= '1';

      wait until (o_ready and g_ready) for 200 ms;
      
      pnt := 0;
      calc_error : for i in 0 to 26 loop
        err := abs(signed(gold(i)(23 downto 0)) - signed(res(i)(23 downto 0)));
        if (err < x"100") then
          pnt := pnt + 1;
        else
          report "Error exceeded at n=" & integer'image(n) & " i=" & integer'image(i) & "   Total error = " & integer'image(to_integer(err));
        end if;
      end loop calc_error;
      if pnt = 27 then
        test_res := test_res + 1;
      end if;

      reset <= '1'; start <= '0'; run_gold <= '0';
      wait for 5 * clockperiod;
      
    end loop test_loop;

    report "passed tests = " & integer'image(test_res);
    keep_simulating <= '0';
    wait;
  end process test;

end architecture sim;
