library ieee;
  use ieee.std_logic_1164.all;
  use ieee.math_real.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity hadamard_tb is
end entity hadamard_tb;

architecture rtl of hadamard_tb is

  component hadamard is
    generic (
      logN  : natural RANGE 1 to 3 := 3;
      N_idx : natural range 0 to 7 := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      start     : in    std_logic;
      x_i       : in    std_logic_vector(24 downto 0);
      y_i       : in    std_logic_vector(24 downto 0);
      x_k       : in    std_logic_vector(24 downto 0);
      y_k       : in    std_logic_vector(24 downto 0); -- s_iiii'iiii.ffff'ffff'ffff'ffff
      lut       : in    std_logic_vector(((logN+1) * 25) - 1 downto 0);
      p_coefs_x : out   std_logic_vector(((logN+1) * 25) - 1 downto 0);
      p_coefs_y : out   std_logic_vector(((logN+1) * 25) - 1 downto 0);
      ready     : buffer std_logic
    );
  end component;

  component b25_cmul is
    port (
      a   : in    std_logic_vector(24 downto 0);
      con : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  signal reset, start : std_logic;
  signal x_i          : std_logic_vector(24 downto 0);
  signal y_i          : std_logic_vector(24 downto 0);
  signal x_k          : std_logic_vector(24 downto 0);
  signal y_k          : std_logic_vector(24 downto 0); -- s_iiii'iiii.ffff'ffff'ffff'ffff
  signal lut          : std_logic_vector((4 * 25) - 1 downto 0);
  signal p_coefs_x    : std_logic_vector((4 * 25) - 1 downto 0);
  signal p_coefs_y    : std_logic_vector((4 * 25) - 1 downto 0);
  signal ready        : std_logic;

  signal   clk             : std_logic := '0';
  signal   keep_simulating : std_logic := '0';  -- delimita o tempo de geração do clock
  constant clockperiod     : TIME      := 1 ms; -- frequencia 1KHz

  constant kcon : std_logic_vector(24 downto 0) := "0000000000011100101010011"; -- kcon = 1 / k^3    0x3953
  -- constant kcon : std_logic_vector(24 downto 0) := "0000000000000001110010101"; -- 4 shifts

  signal p_coefs_x_0, p_coefs_x_1, p_coefs_x_2, p_coefs_x_3 : std_logic_vector(25 - 1 downto 0);

begin

  clk <= (NOT clk) and keep_simulating AFTER clockperiod / 2;

  dut : component hadamard
    generic map (
      logN=>3,
      N_idx=>1
    )
    port map (
      clock=>clk,
      reset=>reset,
      start=>start,
      x_i=>x_i,
      y_i=>y_i,
      x_k=>x_k,
      y_k=>y_k,
      lut=>lut,
      p_coefs_x=>p_coefs_x,
      p_coefs_y=>p_coefs_y,
      ready=>ready
    );

    p_coefs_x_0 <= p_coefs_x(24 downto 0);
    p_coefs_x_1 <= p_coefs_x(49 downto 25);
    p_coefs_x_2 <= p_coefs_x(74 downto 50);
    p_coefs_x_3 <= p_coefs_x(99 downto 75);

  -- lut <= "0000000010000000000000000" & "0000000010000000000000000" & "0000000010000000000000000" & "0000000010000000000000000";
  -- lut <= "0000000000000000101011111" &
  --        "0000000000000001010001001" & -- 2
  --        "0000000000000001101001111" & -- 1
  --        "0000000000000001110010101";
  -- It has like 6 shifts? The fuck?

  lut(24 downto 0) <= kcon;

  lut_mul1 : component b25_cmul
    port map (
      a   => "0000000001110110010000100",
      con => kcon,
      res => lut(49 downto 25)
    );

  lut_mul2 : component b25_cmul
    port map (
      a   => "0000000001011010100000101",
      con => kcon,
      res => lut(74 downto 50)
    );

  lut_mul3 : component b25_cmul
    port map (
      a   => "0000000000110000111111000",
      con => kcon,
      res => lut(99 downto 75)
    );

  -- x_i <= "0000000100000000000000000"; -- 0x2
  -- y_i <= "0000000000000000000000000"; -- 0x0
  -- x_k <= "0000000100000000000000000"; -- 0x2
  -- y_k <= "0000000000000000000000000"; -- 0x0

  x_i <= "0000000000100000000000000"; -- 0x0.4
  y_i <= "0000000010100000111000000"; -- 0x1.41c
  x_k <= "0000000000100000000000000"; -- 0x0.4
  y_k <= "0000000010100000111000000"; -- 0x1.41c

  test : process is
  begin

    keep_simulating <= '1';
    reset           <= '0';
    start           <= '1';

    wait until ready;
    start           <= '0';

    wait for 25 * clockperiod;
    reset           <= '1';
    wait for 5 * clockperiod;
    reset           <= '0';

    wait for 20 * clockperiod;
    keep_simulating <= '0';

    -- report integer'image(to_integer(unsigned(addr))) & " - " & integer'image(to_integer(unsigned(data)));
    -- REPORT INTEGER'image(to_integer(unsigned(res)));
    wait;

  end process test;

end architecture rtl;
