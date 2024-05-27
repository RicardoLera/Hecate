library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;

entity hadamard_uc is
  port (
    clock           : in    std_logic;
    start           : in    std_logic;
    reset           : in    std_logic;
    j_end           : in    std_logic;
    mul_ready       : in    std_logic;
    cordic_feedback : out   std_logic;
    freeze_cordic   : out   std_logic;
    flux_to_cordic  : out   std_logic;
    cordic_rotation : out   std_logic;
    flux_coefs      : out   std_logic;
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

  e_nex <=
    vector_flux  when e_cur = initial      and start = '1'     else
    partial_mul  when e_cur = vector_flux  and j_end = '1'     else
    pre_rotation when e_cur = partial_mul  and mul_ready = '1' else
    rotation     when e_cur = pre_rotation                     else
    final_mul    when e_cur = rotation     and j_end = '1'     else
    final        when e_cur = final_mul    and mul_ready = '1' else
    e_cur;

  with e_cur select cordic_feedback <=
    '1' when vector_flux | rotation,
    '0' when OTHERS;

  with e_cur select flux_to_cordic <=
    '1' when pre_rotation,
    '0' when OTHERS;

  with e_cur select freeze_cordic <=
    '1' when partial_mul | final_mul,
    '0' when OTHERS;

  with e_cur select flux_coefs <=
    '1' when rotation,
    '0' when OTHERS;

  with e_cur select cordic_rotation <=
    '1' when pre_rotation | rotation,
    '0' when OTHERS;

  with e_cur select ready <=
    '1' when final,
    '0' when OTHERS;

end architecture fsm;
