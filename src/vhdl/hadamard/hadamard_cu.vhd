  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;

entity hadamard_cu is
  port (
    clock, start, reset      : in  std_logic;
    polar_latch_ready, j_end : in  std_logic;
    cordic_mode              : out std_logic_vector(1 downto 0);
    ready, rotation          : out std_logic
  );
end entity hadamard_cu;

architecture synth of hadamard_cu is
  signal s_cur : t_had_state := initial;
  signal s_nex : t_had_state;
begin

  process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        s_cur <= initial;
      else
        s_cur <= s_nex;
      end if;
    end if;
  end process;

  s_nex <=
    vector_mul when s_cur = initial    and start = '1'             else
    pre_rot    when s_cur = vector_mul and polar_latch_ready = '1' else
    rot_kmul   when s_cur = pre_rot                                else
    final      when s_cur = rot_kmul   and j_end = '1'             else
    s_cur;

  with s_cur select cordic_mode <=
    "01" when initial,                       -- Set initials (rect -> polar)
    "10" when vector_mul | rot_kmul | final, -- Feedback
    "11" when pre_rot,                       -- Set product (polar -> rect)
    "00" when others;                        -- off

  with s_cur select rotation <=
    '1' when pre_rot | rot_kmul,
    '0' when others;

  with s_cur select ready <=
    '1' when final,
    '0' when others;

end architecture synth;
