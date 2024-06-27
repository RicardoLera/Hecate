library work;
  use work.hecate_pkg.all;

library ieee;
  use ieee.std_logic_1164.all;

entity hadamard_uc is
  port (
    clock, start, reset    : in     std_logic;
    j_end, mul_ready       : in     std_logic;
    cordic_mode, flux_mode : out    std_logic_vector(1 downto 0);
    rotation               : out    std_logic;
    ready                  : buffer std_logic
  );
end entity hadamard_uc;

architecture fsm of hadamard_uc is

  signal e_cur : t_state := initial;
  signal e_nex : t_state;

begin

  process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        e_cur <= initial;
      else
        e_cur <= e_nex;
      end if;
    end if;
  end process;

  e_nex <=
    vector_flux when e_cur = initial     and start = '1'     else
    pre_rot     when e_cur = vector_flux and j_end = '1'     else
    rot_coef    when e_cur = pre_rot                         else
    final       when e_cur = rot_coef    and mul_ready = '1' else
    e_cur;

  with e_cur select cordic_mode <=
    "01" when initial,                -- Set initials
    "10" when vector_flux | rot_coef, -- Feedback
    "11" when pre_rot,                -- Set product
    "00" when others;                 -- off

  with e_cur select flux_mode <=
    "00" when initial,                -- Set zero
    "01" when vector_flux,            -- Polar mul
    "10" when rot_coef,               -- Coefs mul
    "11" when others;                 -- copy

  with e_cur select rotation <=
    '1' when pre_rot | rot_coef,
    '0' when others;

  with e_cur select ready <=
    '1' when final,
    '0' when others;

end architecture fsm;
