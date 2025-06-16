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

  azq <=
    ("00", mzero ) when (not sel_a(3) and sel_a(0)) else -- a = 0
    ("01", mzero ) when (not sel_a(2) and sel_a(1)) else -- a = pi/2
    ("10", mzero ) when (    sel_a(3) and sel_a(0)) else -- a = pi
    ("11", mzero ) when (    sel_a(2) and sel_a(1)) else -- a = 3pi/2
    ("00", azm   ) when (sel_a = "0000") else -- 0     < a < pi/2
    ("01", azmi  ) when (sel_a = "1000") else -- pi/2  < a < pi
    ("10", azm   ) when (sel_a = "1100") else -- pi    < a < 3pi/2
    ("11", azmi  ) when (sel_a = "0100") else -- 3pi/2 < a < 2pi (0)
    (others => '0'); -- unreachable

  bzq <=
    ("00", mzero ) when (not sel_b(3) and sel_b(0)) else -- b = 0
    ("01", mzero ) when (not sel_b(2) and sel_b(1)) else -- b = pi/2
    ("10", mzero ) when (    sel_b(3) and sel_b(0)) else -- b = pi
    ("11", mzero ) when (    sel_b(2) and sel_b(1)) else -- b = 3pi/2
    ("00", bzm   ) when (sel_b = "0000") else -- 0     < b < pi/2
    ("01", bzmi  ) when (sel_b = "1000") else -- pi/2  < b < pi
    ("10", bzm   ) when (sel_b = "1100") else -- pi    < b < 3pi/2
    ("11", bzmi  ) when (sel_b = "0100") else -- 3pi/2 < b < 2pi (0)
    (others => '0'); -- unreachable

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

-- Vivado doesn't understand this, despite claiming to support VHDL-2008 and manually setting all files to the standard. So if-chain it is.
-- process(all) begin -- convert bz0 -> bzq
--   case? sel_b is
--     when "0--1" => azq <= ("00", mzero ); -- a = 0           
--     when "-01-" => azq <= ("01", mzero ); -- a = pi/2
--     when "1--1" => azq <= ("10", mzero ); -- a = pi
--     when "-11-" => azq <= ("11", mzero ); -- a = 3pi/2
--     when "0000" => azq <= ("00", azm   ); -- 0     < a < pi/2
--     when "1000" => azq <= ("01", azmi  ); -- pi/2  < a < pi
--     when "1100" => azq <= ("10", azm   ); -- pi    < a < 3pi/2
--     when "0100" => azq <= ("11", azmi  ); -- 3pi/2 < a < 2pi (0)
--     when others => azq <= (others => '0');
--   end case?;
-- end process;