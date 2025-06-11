  use work.hecate_pkg.all;
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity pfb_qadd is
  port (
    ax, ay, bx, by : in  t_signed; -- rectangular coordinates of input
    az0, bz0       : in  t_pfb;    -- polar angles (q0) of input
    sz0            : out t_pfb;    -- polar angle (q0) of sum (for cordic)
    sxs, sys       : out std_logic -- rectangular signs of sum (for correction)
  );
end entity pfb_qadd;

architecture synth of pfb_qadd is
  constant mzero                         : signed(pfb_size-3 downto 0) := (others => '0');
  signal axs, ays,  bxs, bys             : std_logic;
  signal axm, aym,  bxm, bym             : signed(signed_size-2 downto 0);
  signal azm, azmi, bzm, bzmi, szm, szmi : signed(pfb_size-3 downto 0);
  signal azq, bzq, szq                   : t_pfb;
  signal sel_a, sel_b                    : std_logic_vector(3 downto 0);
  signal sel_s                           : std_logic_vector(2 downto 0);
begin
  axs   <= ax(signed_size-1); axm <= ax(signed_size-2 downto 0);
  ays   <= ay(signed_size-1); aym <= ay(signed_size-2 downto 0);
  azm   <= az0(pfb_size-3 downto 0); azmi <= not(azm)+1;
  sel_a <= axs & ays & nor(axm) & nor(aym);

  bxs   <= bx(signed_size-1); bxm <= bx(signed_size-2 downto 0);
  bys   <= by(signed_size-1); bym <= by(signed_size-2 downto 0);
  bzm   <= bz0(pfb_size-3 downto 0); bzmi <= not(bzm)+1;
  sel_b <= bxs & bys & nor(bxm) & nor(bym);

  szq   <= azq + bzq;
  szm   <= szq(pfb_size-3 downto 0); szmi <= not(szm)+1;
  sel_s <= szq(pfb_size-1) & szq(pfb_size-2) & nor(szq(pfb_size -3 downto 0));

  process(all) begin -- convert az0 -> azq
    case? sel_a is
      when "0--1" => azq <= ("00", mzero ); -- a = 0
      when "-01-" => azq <= ("01", mzero ); -- a = pi/2
      when "1--1" => azq <= ("10", mzero ); -- a = pi
      when "-11-" => azq <= ("11", mzero ); -- a = 3pi/2
      when "0000" => azq <= ("00", azm   ); -- 0     < a < pi/2
      when "1000" => azq <= ("01", azmi  ); -- pi/2  < a < pi
      when "1100" => azq <= ("10", azm   ); -- pi    < a < 3pi/2
      when "0100" => azq <= ("11", azmi  ); -- 3pi/2 < a < 2pi (0)
      when others => azq <= (others => '0'); -- unreachable
    end case?;
  end process;

  process(all) begin -- convert bz0 -> bzq
    case? sel_b is
      when "0--1" => bzq <= ("00", mzero ); -- b = 0
      when "-01-" => bzq <= ("01", mzero ); -- b = pi/2
      when "1--1" => bzq <= ("10", mzero ); -- b = pi
      when "-11-" => bzq <= ("11", mzero ); -- b = 3pi/2
      when "0000" => bzq <= ("00", bzm   ); -- 0     < b < pi/2
      when "1000" => bzq <= ("01", bzmi  ); -- pi/2  < b < pi
      when "1100" => bzq <= ("10", bzm   ); -- pi    < b < 3pi/2
      when "0100" => bzq <= ("11", bzmi  ); -- 3pi/2 < b < 2pi (0)
      when others => bzq <= (others => '0'); -- unreachable
    end case?;
  end process;

  process(all) begin -- convert szq -> sz0
    case? sel_s is
      when "001" => sz0 <= ("00", mzero ); sxs <= '0'; sys <= '0'; -- s = 0     (second sign arbitrary)
      when "011" => sz0 <= ("01", mzero ); sys <= '0'; sxs <= '0'; -- s = pi/2  (second sign arbitrary)
      when "101" => sz0 <= ("00", mzero ); sxs <= '1'; sys <= '0'; -- s = pi    (second sign arbitrary)
      when "111" => sz0 <= ("01", mzero ); sys <= '1'; sxs <= '0'; -- s = 3pi/2 (second sign arbitrary)
      when "000" => sz0 <= ("00", szm   ); sxs <= '0'; sys <= '0'; -- 0     < s < pi/2
      when "010" => sz0 <= ("00", szmi  ); sxs <= '1'; sys <= '0'; -- pi/2  < s < pi
      when "100" => sz0 <= ("00", szm   ); sxs <= '1'; sys <= '1'; -- pi    < s < 3pi/2
      when "110" => sz0 <= ("00", szmi  ); sxs <= '0'; sys <= '1'; -- 3pi/2 < s < 2pi (0)
      when others => sz0 <= (others => '0'); sxs <= '0'; sys <= '0'; -- unreachable
    end case?;
  end process;

end architecture synth;