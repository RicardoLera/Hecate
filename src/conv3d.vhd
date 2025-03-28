  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity conv3d is
  port (
    img : in  b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
    ker : in  b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
    clk : in  std_logic;
    rst : in  std_logic;
    run : in  std_logic;
    res : out b25_real_array(0 to 26);
    rdy : out std_logic
  );
end entity conv3d;

architecture synth of conv3d is

  constant isize  : integer := 2;
  constant osize  : integer := 3;

  signal rdy_sub        : std_logic_vector(26 downto 0) := (others => '0');

  signal mul_a, mul_b, mul_res : b25_real_array(26 downto 0) := (others => (others => '0'));
  signal add_a, add_b          : b25_real_array(26 downto 0) := (others => (others => '0'));
  
begin

  add_b <= mul_res;

  loop_oz : for oz in 0 to osize-1 generate
    loop_oy : for oy in 0 to osize-1 generate
      loop_ox : for ox in 0 to osize-1 generate

        constant oidx : integer := ox + oy*osize + oz*osize*osize;

      begin

        mul : component b25_mul
          port map (
            a   => mul_a(oidx),
            b   => mul_b(oidx),
            res => mul_res(oidx)
          );
        
        add : component b25_add
          port map (
            a   => add_a(oidx),
            b   => add_b(oidx),
            res => res(oidx)
          );
        
        macc : process(clk)
          constant pad : integer := 1;
          variable ix, iy, iz : integer := 0;
          variable kx, ky, kz : integer := 0;
        begin
          if (rising_edge(clk)) then
            if (rst) then
              mul_a(oidx) <= (others => '0');
              mul_b(oidx) <= (others => '0');
              add_a(oidx) <= (others => '0');

              rdy_sub(oidx) <= '0';
              kz := 0;

            elsif (run) then

              loop_kz : if kz < isize then
                iz := oz + kz - pad;
                loop_ky : if ky < isize then
                  iy := oy + ky - pad;
                  loop_kx : if kx < isize then
                    ix := ox + kx - pad;
                    
                    if ((ix >= 0) and (ix < isize) and (iy >= 0) and (iy < isize) and (iz >= 0) and (iz < isize)) then

                      mul_a(oidx) <= img(ix)(iy)(iz);
                      mul_b(oidx) <= ker(kx)(ky)(kz);
                      add_a(oidx) <= res(oidx); 

                    end if;

                    kx := kx + 1;
                  else
                    ky := ky + 1;
                    kx := 0;
                  end if loop_kx;
                else
                  kz := kz + 1;
                  ky := 0;
                end if loop_ky;
              else
                rdy_sub(oidx) <= '1';
              end if loop_kz;

            end if;
          end if;
        end process macc;

      end generate loop_ox;
    end generate loop_oy;
  end generate loop_oz;

  rdy <= and(rdy_sub);

end architecture synth;