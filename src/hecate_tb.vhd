library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_tb is
end entity hecate_tb;

architecture sim of hecate_tb is

  type test_tuple_t is array(0 to 1) of b25_real_array(7 downto 0);
  signal test_tuple : test_tuple_t;

  signal img, ker          : b25_real_array(0 to 7);

  signal clk, reset, start : std_logic := '0';
  signal o_ready           : std_logic;
  signal res               : b25_real_array(0 to 26);

  signal keep_simulating   : std_logic := '0';
  constant clockperiod     : time      := 1 ms;

  signal gold               : b25_real_array(0 to 26);
  signal run_gold           : std_logic := '0';
  constant test_n           : integer := 1;

  impure function rand_slv(len : integer) return std_logic_vector is
    variable seed1 : integer := 1;
    variable seed2 : integer := 1;
    variable r : real;
    variable slv : std_logic_vector(len - 1 downto 0);
  begin
    for i in slv'range loop
      uniform(seed1, seed2, r);
      slv(i) := '1' when r > 0.5 else '0';
    end loop;
    return slv;
  end function;

  procedure rand_arr(signal arr : out b25_real_array(0 to 7)) is begin
    rand_loop : for i in 0 to 7 loop
      arr(i)   <= '0' & rand_slv(8) & rand_slv(16);
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
      res     => gold
    );

  test : process 
    variable test_res : integer := 0;
  begin
    keep_simulating <= '1';

    test_loop : for n in 0 to test_n-1 loop
      rand_arr(img);
      rand_arr(ker);
      wait for 5 * clockperiod;
      reset <= '0'; start <= '1'; run_gold <= '1';

      wait until o_ready for 200 ms;
      if (res = gold) then
        test_res := test_res + 1;
      end if;

      reset <= '1'; start <= '0'; run_gold <= '0';
      wait for 5 * clockperiod;
      
    end loop test_loop;

    keep_simulating <= '0';
    wait;
  end process test;

end architecture sim;
