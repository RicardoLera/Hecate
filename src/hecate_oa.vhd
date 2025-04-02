use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  
entity hecate_oa is
  generic (
    ix, iy, iz : natural range 2 to 16 := 2;
    ox, oy, oz : natural range 3 to 17 := 32
  ); 
  port (
    img                 : in b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
    ker                 : in b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
    clock, reset, start : in std_logic;
    res                 : out b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
    o_ready             : out std_logic
  );
end entity hecate_oa;

architecture synth of hecate_oa is

  constant hec_x : natural := (ox / 2) + (ox mod 2);
  constant hec_y : natural := (oy / 2) + (oy mod 2);
  constant hec_z : natural := (oz / 2) + (oz mod 2);

  type b25_4d_real_array is array (natural range <>) of b25_3d_real_array;
  type b25_5d_real_array is array (natural range <>) of b25_4d_real_array;
  type b25_6d_real_array is array (natural range <>) of b25_5d_real_array;
  signal hec : b25_6d_real_array(0 to hec_z-1)(0 to hec_y-1)(0 to hec_x-1)(0 to 2)(0 to 2)(0 to 2);

begin

  gen_hec_z : for hz in 0 to hec_z-1 generate
    gen_hec_y : for hy in 0 to hec_y-1 generate
      gen_hec_x : for hx in 0 to hec_x-1 generate
        constant sx0 : natural := 
        constant sx1 : natural := 
        constant sy0 : natural := 
        constant sy1 : natural := 
        constant sz0 : natural := 
        constant sz1 : natural := 
      begin
        slice : component hecate
          port map (
            img     => img(sz0 to sz1)(sy0 to sy1)(sx0 to sx1),
            ker     => ker,
            clock   => clock,
            reset   => reset,
            start   => start,
            res     => hec(hz)(hy)(hx),
            o_ready => o_ready
          );
      end generate gen_hec_x;
    end generate gen_hec_y;
  end generate gen_hec_z;

  gen_oz : for g_oz in 0 to oz-1 generate
    gen_oy : for g_oy in 0 to oy-1 generate
      gen_ox : for g_ox in 0 to ox-1 generate

      begin

        process (start) is
          variable s_ox, s_oy, s_oz : natural;
        begin
          if (reset) then

          elsif(start) then

            for hz in 0 to hec_z loop
              for hy in 0 to hec_y loop
                for hx in 0 to hec_x loop
                  for sz in 0 to 2 loop
                    for sy in 0 to 2 loop
                      for sx in 0 to 2 loop
                        s_ox := 
                        s_oy := 
                        s_oz := 
                        if ((g_ox=s_ox) and (g_oy=s_oy) and (g_oz=s_oz)) then
                          res(g_oz)(g_oy)(g_ox) <= std_logic_vector(unsigned(res(g_oz)(g_oy)(g_ox)) + unsigned(hec(hz)(hy)(hx)(sz)(sy)(sx)));
                        end if;
                      end loop;
                    end loop;
                  end loop;
                end loop;
              end loop;
            end loop;

          end if;
        end process;

      end generate gen_ox;
    end generate gen_oy;
  end generate gen_oz;


end architecture synth;