  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity conv3d is
  generic (
    isize : natural := 4;
    osize : natural := 5
  ); 
  port (
    img : in  b25_3d_real_array(0 to isize-1)(0 to isize-1)(0 to isize-1);
    ker : in  b25_3d_real_array(0 to 1)(0 to 1)(0 to 1);
    clk : in  std_logic;
    rst : in  std_logic;
    run : in  std_logic;
    res : out b25_3d_real_array(0 to osize-1)(0 to osize-1)(0 to osize-1);
    rdy : out std_logic
  );
end entity conv3d;

architecture synth of conv3d is

  constant osize_full : integer := osize*osize*osize;

  signal rdy_sub : std_logic_vector(osize_full-1 downto 0) := (others => '0');

  signal mul_a, mul_b, mul_res : b25_real_array(osize_full-1 downto 0) := (others => (others => '0'));
  signal add_a, add_b          : b25_real_array(osize_full-1 downto 0) := (others => (others => '0'));

  signal res_buff : b25_real_array(0 to osize_full-1);
  
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
            res => res_buff(oidx)
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

              loop_kz : if kz < 2 then
                iz := oz + kz - pad;
                loop_ky : if ky < 2 then
                  iy := oy + ky - pad;
                  loop_kx : if kx < 2 then
                    ix := ox + kx - pad;
                    
                    if ((ix >= 0) and (ix < isize) and (iy >= 0) and (iy < isize) and (iz >= 0) and (iz < isize)) then

                      mul_a(oidx) <= img(iz)(iy)(ix);
                      mul_b(oidx) <= ker(1-kz)(1-ky)(1-kx); -- flip kernel
                      add_a(oidx) <= res_buff(oidx); 

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

  --Output Layer (unrasterize)
  gen_z : for z in 0 to osize-1 generate
    gen_y : for y in 0 to osize-1 generate
      gen_x : for x in 0 to osize-1 generate
        constant idx : natural := x + y*osize + z*osize*osize;
      begin
        gen_if : if (idx < osize_full) generate
          res(z)(y)(x) <= res_buff(idx) when rdy = '1' else (others => '0');
        end generate gen_if;
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

end architecture synth;