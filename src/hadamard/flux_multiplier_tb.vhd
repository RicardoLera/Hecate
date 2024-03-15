library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity flux_multiplier_tb is
end entity flux_multiplier_tb;

architecture rtl of flux_multiplier_tb is

  component flux_multiplier is
    generic (
      size      : natural := 8;
      frac_size : natural := 4;
      lut_size  : natural range 1 to 4 := 1
    );
    port (
      clock   : in    std_logic;
      reset   : in    std_logic;
      run     : in    std_logic;
      a       : in    std_logic_vector(size - 1 downto 0);
      b       : in    std_logic_vector(size - 1 downto 0);
      a_nex   : in    std_logic_vector(size - 1 downto 0);
      b_nex   : in    std_logic_vector(size - 1 downto 0);
      lut     : in    std_logic_vector((lut_size * size) - 1 downto 0);
      coefs_x : out   std_logic_vector((lut_size * size) - 1 downto 0);
      coefs_y : out   std_logic_vector((lut_size * size) - 1 downto 0);
      p       : out   std_logic_vector(size - 1 downto 0);
      ready   : out   std_logic
    );
  end component;

  signal clk   : std_logic                              := '1';
  signal res   : std_logic                              := '0';
  signal run   : std_logic                              := '0';
  signal ready : std_logic                              := '0';
  signal a     : std_logic_vector(7 downto 0)           := (OTHERS => '0');
  signal b     : std_logic_vector(7 downto 0)           := (OTHERS => '0');
  signal an    : std_logic_vector(7 downto 0)           := (OTHERS => '0');
  signal bn    : std_logic_vector(7 downto 0)           := (OTHERS => '0');
  signal o     : std_logic_vector(7 downto 0)           := (OTHERS => '0');
  signal cx    : std_logic_vector((1 * 8) - 1 downto 0) := (OTHERS => '0');
  signal cy    : std_logic_vector((3 * 8) - 1 downto 0) := (OTHERS => '0');
  signal lx    : std_logic_vector((1 * 8) - 1 downto 0) :=
         (
          "00000110"
       );
  signal ly    : std_logic_vector((3 * 8) - 1 downto 0) :=
         (
          "00000010" &
         "00000111" &
         "00001110"
       );

  signal   keep_simulating : std_logic := '0';  -- delimita o tempo de geração do clock
  constant clockperiod     : TIME      := 1 ms; -- frequencia 1KHz

  type t_log is ARRAY (NATURAL RANGE <>) OF std_logic_vector(7 downto 0);

  constant log_a : t_log(10 downto 0) :=
  (
    "00011110",
    "00011110",
    "00011110",
    "01011110",
    "01011110",
    "01001110",
    "01000110",
    "01000110",
    "01000110",
    "01000111",
    "01000111"
  );
  constant log_b : t_log(10 downto 0) :=
  (
    "01000111",
    "01000111",
    "01000111",
    "00000111",
    "00000111",
    "00010111",
    "00011111",
    "00011111",
    "00011111",
    "00011110",
    "00011110"
  );

begin

  clk <= (NOT clk) and keep_simulating AFTER clockperiod / 2;

  dut : component flux_multiplier
    generic map (
8, 4, 1, 3
    )
    port map (
clk,
 res,
 run,
 a,
 b,
 an,
 bn,
 lx,
 ly,
 cx,
 cy,
 o,
 ready
    );

  test : process is
  begin

    keep_simulating <= '1';
    run             <= '1';
    an              <= log_a(10);
    bn              <= log_b(10);

    for i IN 10 downto 1 loop

      WAIT FOR clockperiod;
      a  <= log_a(i);
      an <= log_a(i - 1);
      b  <= log_b(i);
      bn <= log_b(i - 1);

    end loop;

    wait for 10 * clockperiod;
    keep_simulating <= '0';
    -- report integer'image(to_integer(unsigned(addr))) & " - " & integer'image(to_integer(unsigned(data)));
    -- REPORT INTEGER'image(to_integer(unsigned(res)));
    WAIT;

  end process test;

end architecture rtl;
