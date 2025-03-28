library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

  entity lsp is
    generic (
      n_points   : integer range 0 to 64
    );
    port (
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end entity lsp;

architecture sim of lsp is

  constant the_log : integer := integer(ceil(log2(real(n_points))));

  -- would records fix this?
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  --type b25_complex_matrix is array (natural range <>, natural range <>) of b25_complex; -- this is a multidimensional 2D array of b25_complex
  type b25_complex_array is array (integer range <>) of b25_complex;
  type b25_2d_complex_array is array (integer range <>) of b25_complex_array;             -- this is a once-nested array of b25_complex
  --type b25_3d_complex_array is array (natural range <>) of b25_2d_complex_array;

  signal bfly_in : b25_2d_complex_array(0 to integer(n_points/2-1))(0 to 1) := (others => (others => (others => (others => '0'))));

  signal state : integer := 0;

  type integer_pair is array(0 to 1) of integer;

  function bfly_lut(s, n : integer) return integer_pair is
    variable b, tb : integer;
  begin
    if ((s < 1) or (s > the_log)) then
      return (0,0);
    else
      b  := (n/(2**s)) * (2**(s-1)) + (n mod (2**(s-1))); -- bfly_pos = bfly_group*group_size + pos_in_group
      -- Yes, (n/(2**s)) * (2**(s-1)) = n/2, except NOT because rounding. Leave it like that, it's synth time

      tb := 1 when (n mod (2**s) < 2**(s-1)) else 0;
      return (b, tb);
    end if;
  end function;

begin

  state_machine : process (clock) begin
    if rising_edge(clock) then
      if (reset) then
        state <= 0;
        s_ready <= '0';
      elsif (start) then
        if (state < the_log+1) then
          state <= state + 1;
        else
          s_ready <= '1';
        end if;
      end if;
    end if;
  end process state_machine;

-- n := bfly_lutALT(state, b, tb);

  gen_procs_bfly : for b in 0 to n_points/2-1 generate
    gen_procs_bfly_tb : for tb in 0 to 1 generate
      proc_bfly : process (state) is
      begin
        for n in 0 to n_points-1 loop
          if ((b = bfly_lut(state, n)(0)) and (tb = bfly_lut(state, n)(1))) then
            bfly_in(b)(tb) <= (std_logic_vector(to_unsigned(state, 25)), 25b"0");
          end if;
        end loop;
      end process proc_bfly;
    end generate gen_procs_bfly_tb;
  end generate gen_procs_bfly;

  -- -- Concurrent Processes
  -- gen_procs_bfly : for n in 0 to n_points-1 generate

  --   b_idx(n)  <= bfly_lut(state+1, n)(0);
  --   tb_idx(n) <= bfly_lut(state+1, n)(1);

  --   proc_bfly : process (state) is
  --     --variable b, tb : integer;
  --   begin
  --     if (state > 0 and state < the_log) then
  --       report "process trigger";

  --       --b  := bfly_lut(state, n)(0);
  --       --tb := bfly_lut(state, n)(1);
        
  --       --report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b) & "   tb = " & integer'image(tb) ;

  --       report "state = " & integer'image(state) & "   n = " & integer'image(n) & "   b = " & integer'image(b_idx(n)) & "   tb = " & integer'image(tb_idx(n));

  --       bfly_in(b_idx(n))(tb_idx(n))(0) <= "0000000000000000000000101";

  --       report integer'image(to_integer(unsigned(bfly_in(b_idx(n))(tb_idx(n))(0))));
  --     end if;

  --   end process proc_bfly;
  -- end generate gen_procs_bfly;

end architecture sim;