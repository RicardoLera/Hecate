  use work.hecate_pkg.all;
  
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_oa_tb is
  generic (
    test_n : natural := 2
  );
  -- port (
  --   rom_serial   : in  std_logic_vector(24 downto 0) := (others => '0');
  --   ram_serial   : out std_logic_vector(24 downto 0) := (others => '0');
  --   clock, start : in  std_logic := '0';
  --   reset        : in  std_logic := '1';
  --   ready        : out std_logic := '0'
  -- );
end entity hecate_oa_tb;



-----SIMULATION ARCHITECTURE-----

architecture sim of hecate_oa_tb is

  signal clk, sta : std_logic := '0';
  signal rst      : std_logic := '1';
  signal img      : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal ker      : b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);

  signal res, gold        : b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
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

  procedure rand_arr(signal arr : out b25_3d_real_array; constant offset, size_z, size_y, size_x : in integer) is begin
    for z in 0 to size_z-1 loop
      for y in 0 to size_y-1 loop
        for x in 0 to size_x-1 loop
          arr(z)(y)(x) <= '0' & "00000000" & rand_slv(16, x+y+z+1, x+y+z+1+offset);
        end loop;
      end loop;
    end loop;
  end procedure;

begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hecate_oa
    port map (
      img   => img,
      ker   => ker,
      clock => clk,
      reset => rst,
      start => sta,
      res   => res,
      ready => o_ready
    );

  golden : component conv3d
    port map (
      img => img,
      ker => ker,
      clk => clk,
      rst => rst,
      run => sta,
      res => gold,
      rdy => g_ready
    );

  test : process
    variable t1, t2, test_time, t_mean, t_max, t_min : time := 0 ns;
    variable test_res, pnt : integer  := 0;
    variable err, err_mean : std_logic_vector(23 downto 0) := (others => '0');
  begin
    keep_simulating <= '1';
    rst <= '1';

    test_loop : for n in 0 to test_n-1 loop
      rand_arr(img, n+1, iz, iy, ix); -- ASSUMES SAME SIZE Is AND Ks
      rand_arr(ker, n+2, kz, ky, kx);

      -- img_loop_z : for z in 0 to iz-1 loop
      --   img_loop_y : for y in 0 to iy-1 loop
      --     img_loop_x : for x in 0 to ix-1 loop
      --       img(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
      --     end loop img_loop_x;
      --   end loop img_loop_y;
      -- end loop img_loop_z;

      -- ker_loop_z : for z in 0 to kz-1 loop
      --   ker_loop_y : for y in 0 to ky-1 loop
      --     ker_loop_x : for x in 0 to kx-1 loop
      --       ker(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
      --     end loop ker_loop_x;
      --   end loop ker_loop_y;
      -- end loop ker_loop_z;

      -- img(0)(0)(1) <= '0' & "00000000" & "1000000000000000";
      -- ker(0)(0)(1) <= '0' & "00000000" & "1000000000000000";

      wait for 5 * clockperiod;
      rst <= '0'; sta <= '1'; t1 := now;

      wait until (o_ready and g_ready); t2 := now;

      test_time := t2-t1;
      t_mean := t_mean + test_time;
      if (test_time > t_max) then t_max := test_time; end if;
      if (test_time < t_min or t_min = 0 ns) then t_min := test_time; end if;
      
      pnt := 0; 
      calc_error_z : for z in 0 to oz-1 loop
        calc_error_y : for y in 0 to oy-1 loop
          calc_error_x : for x in 0 to ox-1 loop
            err := std_logic_vector(abs(signed(gold(z)(y)(x)(23 downto 0)) - signed(res(z)(y)(x)(23 downto 0))));
            err_mean := std_logic_vector(unsigned(err_mean) + unsigned(err));

            if (err < x"1000") then
              pnt := pnt + 1;
            else
              report "Error exceeded at (" & integer'image(z) & ")(" & integer'image(y) & ")(" & integer'image(x) & ")" & "   Total error = " & to_hstring(err);
            end if;
          end loop calc_error_x;
        end loop calc_error_y;
      end loop calc_error_z;
      if pnt = oz*oy*ox then
        test_res := test_res + 1;
      end if;

      rst <= '1'; sta <= '0';
      wait for 5 * clockperiod;
      
    end loop test_loop;

    t_mean   := t_mean / test_n;
    err_mean := std_logic_vector(unsigned(err_mean) / to_unsigned(oz*oy*ox, 24));

    report "Passed tests = " & integer'image(test_res) & " out of " & integer'image(test_n);
    report "Max test time = " & integer'image( t_max / clockperiod ) & " cycles";
    report "Min test time = " & integer'image( t_min / clockperiod ) & " cycles";
    report "Average test time = " & real'image( real(t_mean / (1 fs)) * 1.0/1000000000000.0 ) & " cycles";
    report "Average precision error = " & to_hstring(err_mean(23 downto 16)) & "." & to_hstring(err_mean(15 downto 0));

    keep_simulating <= '0';
    wait;
  end process test;

end architecture sim;



-----SYNTHESIZEABLE ARCHITECTURE-----

-- architecture synth of hecate_oa_tb is

--   signal img      : b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
--   signal res      : b25_3d_real_array(0 to iz)(0 to iy)(0 to ix);
--   signal oa_ready, oa_start : std_logic := '0';

--   constant test_ker : b25_3d_real_array(0 to 1)(0 to 1)(0 to 1) := (      -- Specific K
--     ( ( "0000000010000000000000000",
--         "0000000001000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) ),
--     ( ( "0000000010000000000000000",
--         "0000000001000000000000000" ),
--       ( "0000000010000000000000000",
--         "0000000010000000000000000" ) )
--   );

-- begin

--   serial_in : process (clock) is
--     variable oz, oy, ox : natural := 0;
--   begin
--     if rising_edge(clock) then
--       if reset then
--         oz := 0; oy := 0; ox := 0;
--         oa_start <= '0';
--       elsif (start and not oa_start) then
--         img(oz)(oy)(ox) <= rom_serial;
--         ox := ox + 1;
--         if (ox > ix) then oy := oy + 1; ox := 0; end if;
--         if (oy > iy) then oz := oz + 1; oy := 0; end if;
--         if (oz > iz) then oa_start <= '1'; end if;
--       end if;
--     end if;
--   end process serial_in;

--   dut : component hecate_oa
--     port map (
--       img   => img,
--       ker   => test_ker,
--       clock => clock,
--       reset => reset,
--       start => oa_start,
--       res   => res,
--       ready => oa_ready
--     );

--   serial_out : process (clock) is
--     variable oz, oy, ox : natural := 0;
--   begin
--     if rising_edge(clock) then
--       if reset then
--         oz := 0; oy := 0; ox := 0;
--         ready <= '0';
--       elsif (start and oa_ready and not ready) then
--         ram_serial <= res(oz)(oy)(ox);
--         ox := ox + 1;
--         if (ox > ix) then oy := oy + 1; ox := 0; end if;
--         if (oy > iy) then oz := oz + 1; oy := 0; end if;
--         if (oz > iz) then ready <= '1'; end if;
--       end if;
--     end if;
--   end process serial_out;

-- end architecture synth;