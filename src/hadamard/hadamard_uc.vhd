library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;

entity hadamard_uc is
  port (
    clock           : in    std_logic;
    start           : in    std_logic;
    reset           : in    std_logic;
    mul_ready       : in    std_logic;
    j_end           : in    std_logic;
    load_change     : out   std_logic;
    cordic_feedback : out   std_logic;
    flux_to_cordic  : out   std_logic;
    freeze_terms    : out   std_logic;
    mul_xy          : out   std_logic;
    cordic_rotation : out   std_logic;
    ready           : buffer std_logic
  );
end entity hadamard_uc;

architecture fsm of hadamard_uc is

  signal e_cur : t_state := initial;
  signal e_nex : t_state;

begin

  process (clock) is
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        e_cur <= initial;
      else
        e_cur <= e_nex;
      end if;
    end if;
  end process;

  e_nex <= vectorization when e_cur = initial and start = '1' else
           partialmultiplication when e_cur = vectorization and j_end = '1' else
           prerotation when e_cur = partialmultiplication and mul_ready = '1' else
           rotation when e_cur = prerotation else
           finalmultiplication when e_cur = rotation and j_end = '1' else
           finished when e_cur = finalmultiplication and mul_ready = '1' else
           e_cur;

  with e_cur select load_change <=
    '1' when initial | prerotation,
    '0' when OTHERS;

  with e_cur select cordic_feedback <=
    '1' when vectorization | rotation,
    '0' when OTHERS;

  with e_cur select flux_to_cordic <=
    '1' when prerotation,
    '0' when OTHERS;

  with e_cur select freeze_terms <=
    '1' when partialmultiplication | finalmultiplication,
    '0' when OTHERS;

  with e_cur select mul_xy <=
    '1' when rotation,
    '0' when OTHERS;

  with e_cur select cordic_rotation <=
    '1' when prerotation | rotation,
    '0' when OTHERS;

  with e_cur select ready <=
    '1' when finished,
    '0' when OTHERS;

end architecture fsm;
