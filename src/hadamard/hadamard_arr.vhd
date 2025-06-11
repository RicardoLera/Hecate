  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity hadamard_arr is
  port (
    img_transf, ker_transf : in  t_signed_complex_array(0 to n_points/2);
    clock, reset, start    : in  std_logic;
    res                    : out t_signed_complex_array(0 to n_points/2);
    ready                  : out std_logic
  );
end entity hadamard_arr;

architecture synth of hadamard_arr is
  signal ready_had           : std_logic_vector(0 to n_points/2);
  signal hads_ready, s_ready : std_logic := '0';
begin

  hads_ready  <= and(ready_had);
  sync_ready : process (clock) begin
    if rising_edge(clock) then
      if (reset = '1') then
        s_ready <= '0';
      elsif (hads_ready = '1') then
        s_ready <= '1';
      end if;
    end if;
  end process sync_ready;
  ready <= s_ready;

  gen_calc_vals : for id in 0 to n_points/2 generate
    had : component hadamard
      port map (
        clock => clock,
        reset => reset,
        start => start,
        img   => img_transf(id),
        ker   => ker_transf(id),
        p     => res(id),
        ready => ready_had(id)
      );
  end generate gen_calc_vals;

end architecture synth;