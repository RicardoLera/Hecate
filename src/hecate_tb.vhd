  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_tb is
  generic (
    test_n : integer := 2
  );
  port (
    ram    : out t_ram(0 to test_n)(0 to 2)(0 to 2)(0 to 2)
  );
end entity hecate_tb;



-----SIMULATION ARCHITECTURE-----

-- architecture sim of hecate_tb is

--   signal clock, reset, start : std_logic := '0';
--   signal img, ker          : b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);

--   signal res               : b25_3d_real_array(0 to 2)(0 to 2)(0 to 2);
--   signal o_ready           : std_logic;

--   signal gold              : b25_3d_real_array(0 to 2)(0 to 2)(0 to 2);
--   signal g_ready           : std_logic := '0';

--   signal keep_simulating   : std_logic := '0';
--   constant clockperiod     : time      := 1 ms;

--   impure function rand_slv(len : integer; s1 : integer; s2 : integer) return std_logic_vector is
--     variable r : real;
--     variable slv : std_logic_vector(len - 1 downto 0);
--     variable seed1 : positive := s1;
--     variable seed2 : positive := s2;
--   begin
--     for i in slv'range loop
--       uniform(seed1, seed2, r);
--       slv(i) := '1' when r > 0.5 else '0';
--     end loop;
--     return slv;
--   end function;

--   procedure rand_arr(signal arr : out b25_3d_real_array(0 to 1)(0 to 1)(0 to 1); constant offset : in integer) is begin
--     for z in 0 to 1 loop
--       for y in 0 to 1 loop
--         for x in 0 to 1 loop
--           arr(z)(y)(x) <= '0' & "00000000" & rand_slv(16, x+y+z+1, x+y+z+1+offset);
--         end loop;
--       end loop;
--     end loop;
--   end procedure;

-- begin

--   clock <= (not clock) and keep_simulating after clockperiod / 2;

--   dut : component hecate
--     port map (
--       img     => img,
--       ker     => ker,
--       clock   => clock,
--       reset   => reset,
--       start   => start,
--       res     => res,
--       o_ready => o_ready
--     );

--   test : process
--     variable t1, t2, test_time, t_mean, t_max, t_min : time := 0 ns;
--     variable test_res, pnt : integer := 0;
--     variable err           : signed(23 downto 0);
--   begin
--     keep_simulating <= '1';

--     test_loop : for n in 0 to test_n-1 loop
--       rand_arr(img, n+1);
--       rand_arr(ker, n+2);
      
--       -- one_loop_z : for z in 0 to 1 loop
--       --   one_loop_y : for y in 0 to 1 loop
--       --     one_loop_x : for x in 0 to 1 loop
--       --       img(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
--       --       ker(z)(y)(x) <= '0' & "00000001" & "0000000000000000";
--       --     end loop one_loop_x;
--       --   end loop one_loop_y;
--       -- end loop one_loop_z;

--       -- img(0)(0)(1) <= '0' & "00000000" & "1000000000000000";
--       -- ker(0)(0)(1) <= '0' & "00000000" & "1000000000000000";

--       wait for 5 * clockperiod;
--       reset <= '0'; start <= '1'; t1 := now;

--       wait until (o_ready and g_ready) for 200 ms; t2 := now;

--       test_time := t2-t1;
--       t_mean := t_mean + test_time;
--       if (test_time > t_max) then t_max := test_time; end if;
--       if (test_time < t_min or t_min = 0 ns) then t_min := test_time; end if;
      
--       pnt := 0; 
--       calc_error_z : for z in 0 to 2 loop
--         calc_error_y : for y in 0 to 2 loop
--           calc_error_x : for x in 0 to 2 loop
--             err := abs(signed(gold(z)(y)(x)(23 downto 0)) - signed(res(z)(y)(x)(23 downto 0)));
--             if (err < x"100") then
--               pnt := pnt + 1;
--             else
--               report "Error exceeded at n=" & integer'image(z*9+y*3+x) & "   Total error = " & integer'image(to_integer(err));
--             end if;
--           end loop calc_error_x;
--         end loop calc_error_y;
--       end loop calc_error_z;
--       if pnt = 27 then
--         test_res := test_res + 1;
--       end if;

--       reset <= '1'; start <= '0';
--       wait for 5 * clockperiod;
      
--     end loop test_loop;

--     t_mean := t_mean / test_n;

--     report "Passed tests = " & integer'image(test_res) & " out of " & integer'image(test_n);
--     report "Max test time = " & integer'image( t_max / clockperiod ) & " cycles";
--     report "Min test time = " & integer'image( t_min / clockperiod ) & " cycles";
--     report "Average test time = " & real'image( real(t_mean / (1 fs)) * 1.0/1000000000000.0 ) & " cycles";

--     keep_simulating <= '0';
--     wait;
--   end process test;

-- end architecture sim;



-----SYNTHESIZEABLE ARCHITECTURE-----

architecture synth of hecate_tb is

  signal clock, start    : std_logic := '0';
  signal reset           : std_logic := '1';
  signal img             : b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);

  signal ker_transf      : b25_complex_array(0 to 16);
  signal ready_ker       : std_logic;

  signal res             : b25_3d_real_array(0 to 2)(0 to 2)(0 to 2);
  signal o_ready         : std_logic;

  signal keep_simulating : std_logic := '1';
  constant clockperiod   : time      := 1 ms;

  type t_rom is array (natural range <>) of b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);

  -- impure function rand_slv(len : integer; s1 : integer; s2 : integer) return std_logic_vector is
  --   variable r : real;
  --   variable slv : std_logic_vector(len - 1 downto 0);
  --   variable seed1 : positive := s1;
  --   variable seed2 : positive := s2;
  -- begin
  --   for i in slv'range loop
  --     uniform(seed1, seed2, r);
  --     slv(i) := '1' when r > 0.5 else '0';
  --   end loop;
  --   return slv;
  -- end function;

  -- impure function gen_data(constant n : in integer) return t_rom is
  --   variable mem : t_rom(0 to n);
  -- begin
  --   data_loop : for i in 0 to n loop
  --     arr_loop : for j in 0 to 7 loop
  --       mem(i)(j) := (
  --         '0' & "00000000" & rand_slv(16, j+1, j+1+i),
  --         '0' & "00000000" & rand_slv(16, j+2, j+2+i),
  --         '0' & "00000000" & rand_slv(16, j+3, j+3+i)
  --       );
  --     end loop arr_loop;
  --   end loop data_loop;
  --   return mem;
  -- end function;

  --constant rom : t_rom(0 to 2*test_n) := gen_data(2*test_n);

  constant rom : t_rom(0 to test_n-1) := (test_ker, others => (others => (others => (others => (others => '0')))));

begin

  clock <= (not clock) and keep_simulating after clockperiod / 2;

  fft_in_ker : component fft
    generic map (2, 2, 2, 32)
    port map (
      i       => test_ker,
      o       => ker_transf,
      clock   => clock,
      start   => start,
      reset   => reset,
      s_ready => ready_ker
    );

  hec : component hecate
    port map (
      img        => img,
      ker_transf => ker_transf,
      ready_ker  => ready_ker,
      clock      => clock,
      reset      => reset,
      start      => start,
      res        => res,
      o_ready    => o_ready
    );

  test : process (clock)
    variable tn : integer := 0;
  begin
    if rising_edge(clock) then

      if (o_ready) then
        if (tn < test_n) then
          ram(tn) <= res;
          start <= '0';
          reset <= '1';
        else
          keep_simulating <= '0';
        end if;
      else
        if (reset) then
          img <= rom(tn);
          start <= '1';
          reset <= '0';
          tn  := tn + 1;
        end if;
      end if;

    end if;
  end process test;

end architecture synth;