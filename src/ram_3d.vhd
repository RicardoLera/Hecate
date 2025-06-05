  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity ram_3d is
  generic (
    num_addr   : integer := 5; -- 1d
    num_rams   : integer := 5; -- 2d (once nested)
    num_blocks : integer := 5  -- 3d (twice nested)
  );
  port (
    clk, we, ena : in  std_logic;
    addr0        : in  std_logic_vector(integer(ceil(log2(real(num_addr))))   downto 0);
    addr1        : in  std_logic_vector(integer(ceil(log2(real(num_rams))))   downto 0);
    addr2        : in  std_logic_vector(integer(ceil(log2(real(num_blocks)))) downto 0);
    din          : in  signed(24 downto 0);
    dout         : out signed(24 downto 0)
  );
end ram_3d;

architecture arch of ram_3d is
  signal mem : s25_3d_real_array(num_blocks-1 downto 0)(num_rams-1 downto 0)(num_addr-1 downto 0);
begin
  dout <= mem(to_integer(unsigned(addr2)))(to_integer(unsigned(addr1)))(to_integer(unsigned(addr0))) when ena else (others => '0');
  process (clk) begin
    if rising_edge(clk) then
      if (ena and we) then
        mem(to_integer(unsigned(addr2)))(to_integer(unsigned(addr1)))(to_integer(unsigned(addr0))) <= din;
      end if;
    end if;
  end process;
end arch;