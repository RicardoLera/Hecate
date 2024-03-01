library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity mul_cos_simm_tb is
end entity mul_cos_simm_tb;

architecture rtl of mul_cos_simm_tb is

  component mul_cos_simm is
    port (
      a     : in    std_logic_vector(15 downto 0);
      const : in    std_logic_vector(15 downto 0);
      res   : out   std_logic_vector(31 downto 0)
    );
  end component;

  signal   clock           : std_logic := '0';
  signal   keep_simulating : std_logic := '0';  -- delimita o tempo de geração do clock
  constant clockperiod     : TIME      := 1 ms; -- frequencia 1KHz

  signal v1, v2 : std_logic_vector(15 downto 0);
  signal res    : std_logic_vector(31 downto 0);

  function to_string (
    a : std_logic_vector
  ) return STRING is

    variable b    : STRING (1 to a'length) := (OTHERS => NUL);
    variable stri : integer                := 1;

  begin

    for i IN a'range loop

      b(stri) := std_logic'image(a((i)))(2);
      stri    := stri + 1;

    end loop;

    RETURN b;

  end function;

begin

  clock <= (NOT clock) and keep_simulating AFTER clockperiod / 2;

  dut : component mul_cos_simm
    port map (
      a     => v1,
      const => v2,
      res   => res
    );

  test : process is

    variable prt : STRING(1 to 1) := " ";

  begin

    v1 <= "0011100101010011";
    v2 <= "1111111111111111";

    WAIT FOR clockperiod;
    -- FOR id IN 0 TO 15 LOOP

    -- prt := " ";
    -- FOR i IN 0 TO res'length - 1 LOOP
    --     prt := prt & res(i)'image;
    -- END LOOP;
    report to_string(res);

    -- REPORT INTEGER'image(to_integer(unsigned(res_dut(id)(0))));
    -- END LOOP;
    -- ASSERT false REPORT "Test: OK" SEVERITY failure;
    keep_simulating <= '0';
    WAIT;

  end process test;

end architecture rtl;
