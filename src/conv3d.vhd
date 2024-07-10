library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity conv3d is
  port (
    img : in  b25_real_array(0 to 7); -- 2x2x2 non-padded
    ker : in  b25_real_array(0 to 7);
    run : in  std_logic;
    clk : in  std_logic;
    rst : in  std_logic;
    rdy : out std_logic;
    res : out b25_real_array(0 to 26) -- 3x3x3
  );
end entity conv3d;

architecture synth of conv3d is

  constant isize  : integer := 2;
  constant osize  : integer := 3;

  type unsigned_1d_array is array (natural range <>) of unsigned(23 downto 0);
  type unsigned_2d_array is array (natural range <>) of unsigned_1d_array;
  type unsigned_3d_array is array (natural range <>) of unsigned_2d_array;

  signal img_3d, ker_3d : unsigned_3d_array(0 to isize-1)(0 to isize-1)(0 to isize-1) := (others => (others => (others => (others => '0'))));
  signal res_3d         : unsigned_3d_array(0 to osize-1)(0 to osize-1)(0 to osize-1) := (others => (others => (others => (others => '0'))));

begin

  loop_iz : for iz in 0 to isize-1 generate
    loop_iy : for iy in 0 to isize-1 generate
      loop_ix : for ix in 0 to isize-1 generate
        img_3d(ix)(iy)(iz)(23 downto 0) <= unsigned(img(ix + iy*2 + iz*4)(23 downto 0));
        ker_3d(isize-1-ix)(isize-1-iy)(isize-1-iz)(23 downto 0) <= unsigned(ker(ix + iy*2 + iz*4)(23 downto 0));
      end generate loop_ix;
    end generate loop_iy;
  end generate loop_iz;

  loop_oz : for oz in 0 to osize-1 generate
    loop_oy : for oy in 0 to osize-1 generate
      loop_ox : for ox in 0 to osize-1 generate

        macc : process(clk)
          constant pad : integer := 1;
          variable ix, iy, iz : integer := 0;
          variable kx, ky, kz : integer := 0;
        begin
          if (rising_edge(clk)) then
            if (rst) then
              res_3d(ox)(oy)(oz) <= (others => '0');
              rdy <= '0';
              kz := 0;
            elsif (run) then

              loop_kz : if kz < isize then
                iz := oz + kz - pad;
                loop_ky : if ky < isize then
                  iy := oy + ky - pad;
                  loop_kx : if kx < isize then
                    ix := ox + kx - pad;
                    
                    if ((ix >= 0) and (ix < isize) and (iy >= 0) and (iy < isize) and (iz >= 0) and (iz < isize)) then
                      res_3d(ox)(oy)(oz) <= res_3d(ox)(oy)(oz) + resize((img_3d(ix)(iy)(iz)) * (ker_3d(kx)(ky)(kz)) srl 16, 24);
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
                rdy <= '1';
              end if loop_kz;

            end if;
          end if;
        end process macc;

        res(ox + oy*3 + oz*9) <= '0' & std_logic_vector(res_3d(ox)(oy)(oz)(23 downto 0));
      end generate loop_ox;
    end generate loop_oy;
  end generate loop_oz;

end architecture synth;