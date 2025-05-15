  use work.hecate_pkg.all;
  
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_oa_tb is
  generic (
    ix, iy, iz : natural := 4;
    test_n     : natural := 2
  );
  port (
    rom : in b8_3d_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
    ram : out b8_3d_array_signed(0 to iz)(0 to iy)(0 to ix);
    clock, start, reset : in std_logic;
    oa_ready            : out std_logic
  );
end entity hecate_oa_tb;



-----SIMULATION ARCHITECTURE-----

architecture sim of hecate_oa_tb is

  signal clk, rst, sta    : std_logic := '0';
  signal img              : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal ker              : b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);

  signal res, gold        : b25_3d_real_array(0 to iz)(0 to iy)(0 to ix);
  signal o_ready, g_ready : std_logic;

  signal keep_simulating  : std_logic := '0';
  constant clockperiod    : time      := 1 ms;

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

  procedure rand_arr(signal arr : out b25_3d_real_array; constant offset : in integer; constant size : in integer) is begin
    for z in 0 to size-1 loop
      for y in 0 to size-1 loop
        for x in 0 to size-1 loop
          arr(z)(y)(x) <= '0' & "00000000" & rand_slv(16, x+y+z+1, x+y+z+1+offset);
        end loop;
      end loop;
    end loop;
  end procedure;

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hecate_oa
    generic map (ix, iy, iz, ix+1, iy+1, iz+1)
    port map (
      img     => img,
      ker     => ker,
      clock   => clk,
      reset   => rst,
      start   => sta,
      res     => res,
      o_ready => o_ready
    );

  golden : component conv3d
    generic map (ix, ix+1)
    port map (
      img     => img,
      ker     => ker,
      run     => sta,
      clk     => clk,
      rst     => rst,
      res     => gold,
      rdy     => g_ready
    );

  test : process
    variable t1, t2, test_time, t_mean, t_max, t_min : time := 0 ns;
    variable test_res, pnt : integer := 0;
    variable err           : signed(23 downto 0);
  begin
    keep_simulating <= '1';
    rst <= '1';

    test_loop : for n in 0 to test_n-1 loop
      rand_arr(img, n+1, ix);
      rand_arr(ker, n+2, 2);
      
      -- one_loop_z : for z in 0 to 1 loop
      --   one_loop_y : for y in 0 to 1 loop
      --     one_loop_x : for x in 0 to 1 loop
      --       img(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
      --       ker(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
      --     end loop one_loop_x;
      --   end loop one_loop_y;
      -- end loop one_loop_z;

      -- img(0)(0)(1) <= '0' & "00000000" & "1000000000000000";
      -- ker(0)(0)(1) <= '0' & "00000000" & "1000000000000000";

      wait for 5 * clockperiod;
      rst <= '0'; sta <= '1'; t1 := now;

      wait until (o_ready and g_ready) for 200 ms; t2 := now;

      test_time := t2-t1;
      t_mean := t_mean + test_time;
      if (test_time > t_max) then t_max := test_time; end if;
      if (test_time < t_min or t_min = 0 ns) then t_min := test_time; end if;
      
      pnt := 0; 
      calc_error_z : for z in 0 to iz loop
        calc_error_y : for y in 0 to iy loop
          calc_error_x : for x in 0 to ix loop
            err := abs(signed(gold(z)(y)(x)(23 downto 0)) - signed(res(z)(y)(x)(23 downto 0)));
            if (err < x"100") then
              pnt := pnt + 1;
            else
              report "Error exceeded at n=" & integer'image(z*iy*ix+y*ix+x) & "   Total error = " & integer'image(to_integer(err));
            end if;
          end loop calc_error_x;
        end loop calc_error_y;
      end loop calc_error_z;
      if pnt = (iz+1)*(iy+1)*(ix+1) then
        test_res := test_res + 1;
      end if;

      rst <= '1'; sta <= '0';
      wait for 5 * clockperiod;
      
    end loop test_loop;

    t_mean := t_mean / test_n;

    report "Passed tests = " & integer'image(test_res) & " out of " & integer'image(test_n);
    report "Max test time = " & integer'image( t_max / clockperiod ) & " cycles";
    report "Min test time = " & integer'image( t_min / clockperiod ) & " cycles";
    report "Average test time = " & real'image( real(t_mean / (1 fs)) * 1.0/1000000000000.0 ) & " cycles";

    keep_simulating <= '0';
    wait;
  end process test;

end architecture sim;



-----SYNTHESIZEABLE ARCHITECTURE-----

architecture synth of hecate_oa_tb is

  signal img             : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal res             : b25_3d_real_array(0 to iz)(0 to iy)(0 to ix);

begin

  b25_z : for z in 0 to iz-1 generate
    b25_y : for y in 0 to iy-1 generate
      b25_x : for x in 0 to ix-1 generate
        img(z)(y)(x) <= (8b"0", rom(z)(y)(x), 9b"0");
      end generate b25_x;
    end generate b25_y;
  end generate b25_z;

  dut : component hecate_oa
    generic map (4, 4, 4, 5, 5, 5)
    port map (
      img     => img,
      ker     => test_ker,
      clock   => clock,
      reset   => reset,
      start   => start,
      res     => res,
      o_ready => oa_ready
    );

  b8_z : for z in 0 to iz generate
    b8_y : for y in 0 to iy generate
      b8_x : for x in 0 to ix generate
        ram(z)(y)(x) <=
          signed(res(z)(y)(x)(17 downto 10))
            when (res(z)(y)(x)(24) = '0') else
          -signed(res(z)(y)(x)(17 downto 10));
      end generate b8_x;
    end generate b8_y;
  end generate b8_z;

end architecture synth;