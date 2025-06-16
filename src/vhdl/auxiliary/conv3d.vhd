  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity conv3d is
  port (
    img : in  t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
    ker : in  t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
    clk : in  std_logic;
    rst : in  std_logic;
    run : in  std_logic;
    res : out t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
    rdy : out std_logic
  );
end entity conv3d;

architecture synth of conv3d is

  constant osize_full : natural := oz*oy*ox;

  signal rdy_sub : std_logic_vector(osize_full-1 downto 0) := (others => '0');

  signal mul_a, mul_b, mul_res : t_signed_real_array(osize_full-1 downto 0) := (others => (others => '0'));
  signal add_a, add_b          : t_signed_real_array(osize_full-1 downto 0) := (others => (others => '0'));

  signal res_buff : t_signed_real_array(0 to osize_full-1);
  
begin

  add_b <= mul_res;

  loop_oz : for ozi in 0 to oz-1 generate
    loop_oy : for oyi in 0 to oy-1 generate
      loop_ox : for oxi in 0 to ox-1 generate

        constant oidx : natural := oxi + oyi*ox + ozi*ox*oy;

      begin

        mul_res(oidx) <= resize((mul_a(oidx) * mul_b(oidx)) sra signed_point, signed_size);
        res_buff(oidx) <= add_a(oidx) + add_b(oidx);
        
        macc : process(clk)
          constant pad_x : integer := kx-1;
          constant pad_y : integer := ky-1;
          constant pad_z : integer := kz-1;
          variable ixi, iyi, izi : integer := 0;
          variable kxi, kyi, kzi : integer := 0;
        begin
          if (rising_edge(clk)) then
            if (rst) then
              mul_a(oidx) <= (others => '0');
              mul_b(oidx) <= (others => '0');
              add_a(oidx) <= (others => '0');

              rdy_sub(oidx) <= '0';
              kzi := 0;

            elsif (run) then

              loop_kz : if kzi < kz then
                izi := ozi + kzi - pad_z;
                loop_ky : if kyi < ky then
                  iyi := oyi + kyi - pad_y;
                  loop_kx : if kxi < kx then
                    ixi := oxi + kxi - pad_x;
                    
                    if ((ixi >= 0) and (ixi < ix) and (iyi >= 0) and (iyi < iy) and (izi >= 0) and (izi < iz)) then

                      mul_a(oidx) <= img(izi)(iyi)(ixi);
                      mul_b(oidx) <= ker(kz-1-kzi)(ky-1-kyi)(kx-1-kxi); -- flip kernel
                      add_a(oidx) <= res_buff(oidx); 

                    end if;

                    kxi := kxi + 1;
                  else
                    kyi := kyi + 1;
                    kxi := 0;
                  end if loop_kx;
                else
                  kzi := kzi + 1;
                  kyi := 0;
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
  gen_z : for z in 0 to oz-1 generate
    gen_y : for y in 0 to oy-1 generate
      gen_x : for x in 0 to ox-1 generate
        constant idx : natural := x + y*ox + z*ox*oy;
      begin
        gen_if : if (idx < osize_full) generate
          res(z)(y)(x) <= res_buff(idx) when rdy = '1' else (others => '0');
        end generate gen_if;
      end generate gen_x;
    end generate gen_y;
  end generate gen_z;

end architecture synth;