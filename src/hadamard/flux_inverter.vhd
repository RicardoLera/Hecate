library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flux_inverter is
  generic (
    size : natural := 8
  );
  port (
    clock    : in    std_logic;
    reset_s  : in    std_logic;
    reset_as : in    std_logic;
    load     : in    std_logic;
    inp      : in    std_logic_vector(size - 1 downto 0);
    nex      : in    std_logic_vector(size - 1 downto 0);
    outp     : out   std_logic_vector(size - 1 downto 0);
    new_bit  : out   std_logic;
    ready    : out   std_logic;
    erro     : out   std_logic
  );
end entity flux_inverter;

architecture synth of flux_inverter is

  signal m_n                : std_logic_vector(size downto 0);
  signal b                  : std_logic_vector(size - 1 downto 0);
  signal filtered           : std_logic_vector(size - 1 downto 0);
  signal filtered_or        : std_logic_vector(size - 1 downto 0);
  signal compared           : std_logic_vector(size - 1 downto 0);
  signal compared_or        : std_logic_vector(size - 1 downto 0);
  signal s_ready,   s_error : std_logic;

  constant m_0              : std_logic_vector(size downto 0) := (0 => '1', OTHERS => '0');
  signal   m                : std_logic_vector(size downto 0) := m_0;
  signal   inp_inv, nex_inv : std_logic_vector(size - 1 downto 0);

begin

  b(size - 1) <= m(size);

  gen_b : for i IN size - 2 downto 0 generate
    b(i) <= b(i + 1) or m(i + 1);
  end generate gen_b;

  filtered <= not b and m(size - 1 downto 0) and inp_inv;
  compared <= ((inp_inv xor nex_inv) and (b or m(size - 1 downto 0)));

  gen_inv : for i IN size - 1 downto 0 generate
    inp_inv(i) <= inp(size - 1 - i);
    nex_inv(i) <= nex(size - 1 - i);

  end generate gen_inv;

  filtered_or(0) <= filtered(0);
  compared_or(0) <= compared(0);

  gen_or : for i IN 1 to size - 1 generate
    filtered_or(i) <= filtered_or(i - 1) or filtered(i);
    compared_or(i) <= compared_or(i - 1) or compared(i);
  end generate gen_or;

  s_error <= compared_or(size - 1);
  erro    <= s_error;

  m_n(0)             <= filtered_or(size - 1);
  m_n(size DOWNTO 1) <= m(size - 1 downto 0);
  s_ready            <= m(size);
  ready              <= s_ready;

  new_bit <= m_n(0);

  outp <= m(size - 1 downto 0) and b(size - 1 downto 0);

  proc : process (reset_as, clock, s_error) is
  begin

    if ((reset_as) = '1') then
      m <= m_0;
    elsif rising_edge(clock) then
      if ((reset_s or s_error) = '1') then
        m <= m_0;
      elsif (s_ready = '1' or load = '0') then
        m <= m;
      else
        m <= m_n;
      end if;
    end if;

  end process proc; -- proc

end architecture synth; -- synth
