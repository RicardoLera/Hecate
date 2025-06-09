  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flux_inverter is
  port (
    clock, reset_s, load : in  std_logic;
    new_bit, ready, err  : out std_logic;
    inp, nex             : in  unsigned(cordic_len-2 downto 0);
    outp                 : out unsigned(cordic_len-2 downto 0)
  );
end entity flux_inverter;

architecture synth of flux_inverter is

  constant m_0                 : unsigned(cordic_len-1 downto 0) := (0 => '1', others => '0');
  signal m                     : unsigned(cordic_len-1 downto 0) := m_0;
  signal m_n                   : unsigned(cordic_len-1 downto 0);
  signal b                     : unsigned(cordic_len-2 downto 0);
  signal filtered, filtered_or : unsigned(cordic_len-2 downto 0) := (others => '0');
  signal compared, compared_or : unsigned(cordic_len-2 downto 0);
  signal inp_inv, nex_inv      : unsigned(cordic_len-2 downto 0);

begin

  proc : process (clock) begin
    if (rising_edge(clock)) then
      if (reset_s) then
        m <= m_0;
      elsif (ready = '1' or load = '0') then
        m <= m;
      else
        m <= m_n;
      end if;
    end if;
  end process proc;

  b(cordic_len-2) <= m(cordic_len-1);

  gen_b : for i in cordic_len-3 downto 0 generate
    b(i) <= b(i + 1) or m(i + 1);
  end generate gen_b;

  filtered <= not b and m(cordic_len-2 downto 0) and inp_inv;
  compared <= ((inp_inv xor nex_inv) and (b or m(cordic_len-2 downto 0)));

  gen_inv : for i in cordic_len-2 downto 0 generate
    inp_inv(i) <= inp(cordic_len-2 - i);
    nex_inv(i) <= nex(cordic_len-2 - i);
  end generate gen_inv;

  filtered_or(0) <= filtered(0);
  compared_or(0) <= compared(0);
  gen_or : for i in 1 to cordic_len-2 generate
    filtered_or(i) <= filtered_or(i - 1) or filtered(i);
    compared_or(i) <= compared_or(i - 1) or compared(i);
  end generate gen_or;
  err <= compared_or(cordic_len-2);

  m_n(0)                     <= filtered_or(cordic_len-2);
  new_bit                    <= m_n(0);
  m_n(cordic_len-1 downto 1) <= m(cordic_len-2 downto 0);
  ready                      <= m(cordic_len-1);

  outp <= m(cordic_len-2 downto 0) and b(cordic_len-2 downto 0);

end architecture synth;
