  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity hecate_tb is
  port (
    rom_serial_i : in  t_signed;
    rom_serial_k : in  t_signed;
    ram_serial   : out t_signed;
    clock, start : in  std_logic;
    reset        : in  std_logic;
    ready        : out std_logic
  );
end entity hecate_tb;



-----SIMULATION ARCHITECTURE-----

architecture sim of hecate_tb is

  signal clk, sta : std_logic := '0';
  signal rst      : std_logic := '1';
  signal img      : t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal ker      : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);

  signal res, gold        : t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
  signal o_ready, g_ready : std_logic;

  signal slice_rdy, ker_rdy : std_logic;
  signal s_test_n           : integer;
  signal keep_simulating    : std_logic := '0';
  constant clockperiod      : time      := 1 ns;
begin

  clk <= (not clk) and keep_simulating after clockperiod / 2;

  dut : component hecate
    port map (
      img         => img,
      ker         => ker,
      clock       => clk,
      reset       => rst,
      start       => sta,
      res         => res,
      ready       => o_ready,
      ker_ready   => ker_rdy,
      slice_ready => slice_rdy
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
    variable test_res, pnt : natural  := 0;
    variable err, err_mean, err_worst                 : unsigned(signed_size-1 downto 0) := (others => '0');
    variable t1, t2, test_time,  t_mean, t_max, t_min : time := 0 ns;
    variable s1, s2, slice_time, s_mean, s_max, s_min : time := 0 ns;

    variable r     : real;
    variable seed1 : positive := test_seed1;
    variable seed2 : positive := test_seed2;
  begin
    keep_simulating <= '1';
    rst <= '1';

    test_loop : for n in 0 to test_n-1 loop
      s_test_n <= n; -- track test_n on waveform

      for z in 0 to iz-1 loop
        for y in 0 to iy-1 loop
          for x in 0 to ix-1 loop
            uniform(seed1, seed2, r);
            img(z)(y)(x) <= to_signed(integer(floor(r * (2.0**signed_point))), signed_size);
          end loop;
        end loop;
      end loop;

      for z in 0 to kz-1 loop
        for y in 0 to ky-1 loop
          for x in 0 to kx-1 loop
            uniform(seed1, seed2, r);
            ker(z)(y)(x) <= to_signed(integer(floor(r * (2.0**signed_point))), signed_size);
          end loop;
        end loop;
      end loop;

      -- img_loop_z : for z in 0 to iz-1 loop
      --   img_loop_y : for y in 0 to iy-1 loop
      --     img_loop_x : for x in 0 to ix-1 loop
      --       img(z)(y)(x) <= signed_one;
      --     end loop img_loop_x;
      --   end loop img_loop_y;
      -- end loop img_loop_z;

      -- ker_loop_z : for z in 0 to kz-1 loop
      --   ker_loop_y : for y in 0 to ky-1 loop
      --     ker_loop_x : for x in 0 to kx-1 loop
      --       ker(z)(y)(x) <= signed_one;
      --     end loop ker_loop_x;
      --   end loop ker_loop_y;
      -- end loop ker_loop_z;

      -- img(0)(0)(1) <= signed_half;
      -- ker(0)(0)(1) <= signed_half;

      wait for 4 * clockperiod;
      rst <= '0'; sta <= '1'; t1 := now;

      calc_slice_z : for z in 0 to slice_z-1 loop
        calc_slice_y : for y in 0 to slice_y-1 loop
          calc_slice_x : for x in 0 to slice_x-1 loop
            if (not ker_rdy) then wait until (ker_rdy) for 1 ms; end if;
            s1 := now; wait until (slice_rdy) for 10 ms; s2 := now;
            slice_time := s2-s1;
            s_mean := s_mean + slice_time;
            if (slice_time > s_max) then s_max := slice_time; end if;
            if (slice_time < s_min or s_min = 0 ns) then s_min := slice_time; end if;
            report "test(" & natural'image(n) & ") slice(" & natural'image(z) & ")(" & natural'image(y) & ")(" & natural'image(x) & ")" & "   Time = " & natural'image(slice_time / clockperiod ) & " cycles";
          end loop calc_slice_x;
        end loop calc_slice_y;
      end loop calc_slice_z;

      wait until (o_ready and g_ready) for 10 ms; t2 := now;
      test_time := t2-t1;
      t_mean := t_mean + test_time;
      if (test_time > t_max) then t_max := test_time; end if;
      if (test_time < t_min or t_min = 0 ns) then t_min := test_time; end if;
      
      pnt := 0; 
      calc_error_z : for z in 0 to oz-1 loop
        calc_error_y : for y in 0 to oy-1 loop
          calc_error_x : for x in 0 to ox-1 loop
            err := unsigned(abs(gold(z)(y)(x) - res(z)(y)(x)));
            if (err > err_worst) then err_worst := err; end if;
            err_mean := unsigned(err_mean) + unsigned(err);
            if (unsigned(err) < x"1000") then
              pnt := pnt + 1;
            else
              report "Error exceeded at (" & natural'image(z) & ")(" & natural'image(y) & ")(" & natural'image(x) & ")" & "   Total error = " & to_hstring(err(err'left-2 downto 0));
            end if;
          end loop calc_error_x;
        end loop calc_error_y;
      end loop calc_error_z;
      if pnt = oz*oy*ox then
        test_res := test_res + 1;
      end if;

      rst <= '1'; sta <= '0';
      
    end loop test_loop;

    t_mean := t_mean / test_n;
    s_mean := s_mean / (test_n*slice_x*slice_y*slice_z);
    err_mean := unsigned(err_mean) / to_unsigned(oz*oy*ox*test_n, signed_size);

    report "Passed tests = " & natural'image(test_res) & " out of " & natural'image(test_n);
    report "Max test time = " & natural'image(t_max / clockperiod ) & " cycles";
    report "Min test time = " & natural'image(t_min / clockperiod ) & " cycles";
    report "Average test time = " & natural'image(natural((real(t_mean / (1 fs)) * 1.0/1000000.0))) & " cycles";
    report "Max slice time = " & natural'image(s_max / clockperiod ) & " cycles";
    report "Min slice time = " & natural'image(s_min / clockperiod ) & " cycles";
    report "Average slice time = " & natural'image(natural((real(s_mean / (1 fs)) * 1.0/1000000.0))) & " cycles";
    report "Max precision error = " & to_hstring(err_worst(signed_size-2 downto signed_point)) & "." & to_hstring(err_worst(signed_point-1 downto 0));
    report "Average precision error = " & to_hstring(err_mean(signed_size-2 downto signed_point)) & "." & to_hstring(err_mean(signed_point-1 downto 0));

    keep_simulating <= '0';
    wait;
  end process test;

end architecture sim;



-----SYNTHESIZEABLE ARCHITECTURE-----

architecture synth of hecate_tb is

  signal img : t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
  signal ker : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
  signal res : t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
  signal oa_ready, oa_start, serial_i_ready, serial_k_ready : std_logic := '0';

begin

  serial_in : process (clock) is
    variable izi, iyi, ixi, kzi, kyi, kxi : natural := 0;
  begin
    if rising_edge(clock) then
      if reset then
        izi := 0; iyi := 0; ixi := 0; kzi := 0; kyi := 0; kxi := 0;
        serial_i_ready <= '0'; serial_k_ready <= '0';
      elsif start then
        if not serial_i_ready then
          img(izi)(iyi)(ixi) <= rom_serial_i;
          ixi := ixi + 1;
          if (ixi = ix) then iyi := iyi + 1; ixi := 0; end if;
          if (iyi = iy) then izi := izi + 1; iyi := 0; end if;
          if (izi = iz) then serial_i_ready <= '1'; end if;
        end if;

        if not serial_k_ready then
          ker(kzi)(kyi)(kxi) <= rom_serial_k;
          kxi := kxi + 1;
          if (kxi = kx) then kyi := kyi + 1; kxi := 0; end if;
          if (kyi = ky) then kzi := kzi + 1; kyi := 0; end if;
          if (kzi = kz) then serial_k_ready <= '1'; end if;
        end if;
      end if;
    end if;
  end process serial_in;
  oa_start <= serial_i_ready and serial_k_ready;

  dut : component hecate
    port map (
      img   => img,
      ker   => ker,
      clock => clock,
      reset => reset,
      start => oa_start,
      res   => res,
      ready => oa_ready
    );

  serial_out : process (clock) is
    variable ozi, oyi, oxi : natural := 0;
  begin
    if rising_edge(clock) then
      if reset then
        ozi := 0; oyi := 0; oxi := 0;
        ready <= '0';
      elsif (start and oa_ready and not ready) then
        ram_serial <= res(ozi)(oyi)(oxi);
        oxi := oxi + 1;
        if (oxi = ox) then oyi := oyi + 1; oxi := 0; end if;
        if (oyi = oy) then ozi := ozi + 1; oyi := 0; end if;
        if (ozi = oz) then ready <= '1'; end if;
      end if;
    end if;
  end process serial_out;

end architecture synth;