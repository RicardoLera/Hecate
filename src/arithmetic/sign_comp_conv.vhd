library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity sign_comp_conv is
  generic (
    size : natural := 32
  );
  port (
    mag_in : in    std_logic_vector(size - 1 downto 0);
    s      : in    std_logic;
    comp   : out   std_logic_vector(size - 1 downto 0)
  );
end entity sign_comp_conv;

architecture synth of sign_comp_conv is

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

  signal negated, summed : std_logic_vector(size - 1 downto 0);

begin

  --    negate : FOR i IN 0 TO size - 1 GENERATE
  --        negated(i) <= NOT mag_in(i);
  --    END GENERATE; -- negate
  --    adder : ripplecarry GENERIC MAP(size) PORT MAP((0 => '1', OTHERS => '0'), negated, '0', summed, OPEN);
  summed <= std_logic_vector(unsigned(NOT mag_in) + to_unsigned(1, size));
  comp   <= summed when s = '1' else
            mag_in;

end architecture synth; -- synth
