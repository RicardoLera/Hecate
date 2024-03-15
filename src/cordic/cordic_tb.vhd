library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;

entity cordic_tb is
end entity cordic_tb;

architecture rtl of cordic_tb is

  component cordic is
    generic (
      z_len      : natural := 36;
      z_lut_len  : natural := 34;
      j_len      : natural := 5;
      coords_len : natural := 25
    );

    -- 36, 34, 5, 25
    port (
      sigma_in  : in    std_logic;
      rotation  : in    std_logic;
      j         : in    std_logic_vector(j_len - 1 downto 0);
      x_in      : in    std_logic_vector(coords_len - 1 downto 0);
      y_in      : in    std_logic_vector(coords_len - 1 downto 0);
      z_in      : in    std_logic_vector(z_len - 1 downto 0);
      x_out     : out   std_logic_vector(coords_len - 1 downto 0);
      y_out     : out   std_logic_vector(coords_len - 1 downto 0);
      z_out     : out   std_logic_vector(z_len - 1 downto 0);
      sigma_out : out   std_logic
    );
  end component;

  type coord_arr_type is ARRAY (NATURAL RANGE <>) OF std_logic_vector(24 downto 0);

  type angle_arr_type is ARRAY (NATURAL RANGE <>) OF std_logic_vector(35 downto 0);

  signal rotation                 : std_logic;
  signal sigma_arr                : std_logic_vector(0 to 32);
  signal x_arr,             y_arr : coord_arr_type (0 to 32);
  signal z_arr                    : angle_arr_type (0 to 32);

  signal db_x_in                     : std_logic_vector(24 downto 0);
  signal db_y_in                     : std_logic_vector(24 downto 0);
  signal db_x_out                    : std_logic_vector(24 downto 0);
  signal db_y_out                    : std_logic_vector(24 downto 0);
  signal db_z_in,           db_z_out : std_logic_vector(35 downto 0);

  signal   keep_simulating, clk : std_logic := '0';
  constant clockperiod          : TIME      := 20 ns;

begin

  clk <= (NOT clk) and keep_simulating AFTER clockperiod / 2;

  dut_arr_for : for i IN 0 to 31 generate

    dut : component cordic
      generic map (
36, 34, 5, 25
      )
      port map (
        sigma_in  => sigma_arr(i),
        rotation  => rotation,
        j         => STD_LOGIC_VECTOR(to_unsigned(i, 5)),
        x_in      => x_arr(i),
        y_in      => y_arr(i),
        z_in      => z_arr(i),
        x_out     => x_arr(i + 1),
        y_out     => y_arr(i + 1),
        z_out     => z_arr(i + 1),
        sigma_out => sigma_arr(i + 1)
      );

  end generate dut_arr_for;

  db_x_in  <= x_arr(0);
  db_y_in  <= y_arr(0);
  db_z_in  <= z_arr(0);
  db_x_out <= x_arr(32);
  db_y_out <= y_arr(32);
  db_z_out <= z_arr(32);

  sigma_arr(0) <= NOT rotation;

  test : process is

    file     text_file                  : text OPEN read_mode IS "MVP\\Quartus\\cordic_tb_data.txt";
    file     output_file                : text OPEN write_mode IS "cordic_tb_output.txt";
    variable text_line, output_line     : line;
    variable ok                         : BOOLEAN;
    variable rot, x, y, z_first, z_last : integer;
  -- VARIABLE char : CHARACTER;
  -- VARIABLE wait_time : TIME;
  -- VARIABLE selector : sel'SUBTYPE;
  -- VARIABLE data : dout'SUBTYPE;

  begin

    keep_simulating <= '1';

    -- rotation <= '1';
    -- x_arr(0) <= "00000000000001100001001010010001";
    -- y_arr(0) <= (others => '0');
    -- z_arr(0) <= "01000000000000000000000000000000000";

    while NOT endfile(text_file) loop

      readline(text_file, text_line);

      -- Skip empty lines and single-line comments
      if (text_line.ALL'length = 0 or text_line.ALL(1) = '#') then
				NEXT;
      end if;

      read(text_line, rot, ok);
      assert ok
        report "Read 'rot' failed for line: " & text_line.ALL
        severity failure;

      if (rot = 1) then
        rotation <= '1';
      else
        rotation <= '0';
      end if;

      read(text_line, x, ok);
      assert ok
        report "Read 'x' failed for line: " & text_line.ALL
        severity failure;
      x_arr(0) <= std_logic_vector(to_signed(x, x_arr(0)'length));

      read(text_line, y, ok);
      assert ok
        report "Read 'y' failed for line: " & text_line.ALL
        severity failure;
      y_arr(0) <= std_logic_vector(to_signed(y, y_arr(0)'length));

      read(text_line, z_first, ok);
      assert ok
        report "Read 'z first' failed for line: " & text_line.ALL
        severity failure;
      z_arr(0)(34 DOWNTO 8) <= std_logic_vector(to_unsigned(z_first, 27));

      read(text_line, z_last, ok);
      assert ok
        report "Read 'z last' failed for line: " & text_line.ALL
        severity failure;
      z_arr(0)(7 DOWNTO 0) <= std_logic_vector(to_unsigned(z_last, 8));

      WAIT FOR clockperiod;

      if (rotation = '1') then
        write(output_line, 1, right, 4);
      else
        write(output_line, 0, right, 4);
      end if;

      for i IN 0 to 32 loop

        write(output_line, to_integer(signed(x_arr(i))), right, 16);
        write(output_line, to_integer(signed(y_arr(i))), right, 16);
        write(output_line, to_integer(unsigned(z_arr(i)(34 DOWNTO 8))), right, 16);
        write(output_line, to_integer(unsigned(z_arr(i)(7 DOWNTO 0))), right, 16);

      end loop;

      writeline(output_file, output_line);

    end loop;

    WAIT FOR clockperiod;
    assert false
      report "fim da simulacao"
      severity note;
    keep_simulating <= '0';

    WAIT;

  end process test;

end architecture rtl;
