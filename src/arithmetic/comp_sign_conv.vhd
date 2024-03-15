library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity comp_sign_conv is
  generic (
    size : natural := 32
  );
  port (
    comp_in : in    std_logic_vector(size - 1 downto 0);
    mag_out : out   std_logic_vector(size - 1 downto 0);
    s       : out   std_logic
  );
end entity comp_sign_conv;

architecture synth of comp_sign_conv is

  component ripplecarry is
    generic (
      size : natural := 8
    );
    port (
      a     : in    std_logic_vector(size - 1 downto 0);
      b     : in    std_logic_vector(size - 1 downto 0);
      c_in  : in    std_logic;
      s     : out   std_logic_vector(size - 1 downto 0);
      c_out : out   std_logic
    );
  end component ripplecarry;

  signal negated, summed : std_logic_vector(size - 1 downto 0) := (OTHERS => '0');
  signal si              : std_logic;

begin

  si <= comp_in(size - 1);
  s  <= si;
  --    negate : FOR i IN 0 TO size - 1 GENERATE
  --        negated(i) <= NOT comp_in(i);
  --    END GENERATE; -- negate

  --    adder : ripplecarry GENERIC MAP(size) PORT MAP((0 => '1', OTHERS => '0'), negated, '0', summed, OPEN);
  summed  <= std_logic_vector(unsigned(NOT comp_in) + to_unsigned(1, size));
  mag_out <= summed when si = '1' else
             comp_in;

end architecture synth; -- synth
