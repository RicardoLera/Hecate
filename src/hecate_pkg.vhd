library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

  -- Main parameters
  constant ix : natural := 7; -- assumes i mod k = 0, use assert in the testbench
  constant iy : natural := 3;
  constant iz : natural := 3;

  constant kx : natural := 7;
  constant ky : natural := 3;
  constant kz : natural := 3;

  constant ox : natural := (ix+kx-1);
  constant oy : natural := (iy+ky-1);
  constant oz : natural := (iz+kz-1);
  
  constant nx : natural := (2*kx-1);
  constant ny : natural := (2*ky-1);
  constant nz : natural := (2*kz-1);

  constant n_points_nopad : natural := nx*ny*nz;
  constant n_points       : natural := integer(2**ceil(log2(real(n_points_nopad))));
  constant the_log        : natural := integer(log2(real(n_points)));

  -- I/O
  type b8_array is array (natural range <>) of std_logic_vector(7 downto 0);  -- maybe make these into records
  type b8_2d_array is array (natural range <>) of b8_array;
  type b8_3d_array is array (natural range <>) of b8_2d_array;
  type b8_array_signed is array (natural range <>) of signed(7 downto 0);
  type b8_2d_array_signed is array (natural range <>) of b8_array_signed;
  type b8_3d_array_signed is array (natural range <>) of b8_2d_array_signed;

  -- 25-bit types
  type b25_real_array is array (natural range <>) of std_logic_vector(24 downto 0);
  type b25_double_array is array (natural range <>) of std_logic_vector(49 downto 0);
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  type b25_complex_array is array (natural range <>) of b25_complex;

  type b25_2d_real_array is array (natural range <>) of b25_real_array;
  type b25_3d_real_array is array (natural range <>) of b25_2d_real_array;
  type b25_2d_complex_array is array (natural range <>) of b25_complex_array;
  type b25_3d_complex_array is array (natural range <>) of b25_2d_complex_array;

  -- Synth TB RAM
  type t_ram is array (natural range <>) of b25_3d_real_array;

  -- Hadamard state list
  type t_state is (initial, vector_flux, pre_rot, rot_coef, final);

  -- 3d padding
  -- type padding is array(0 to 7) of natural range 0 to 32;
  -- constant pad3d : padding := (0, 1,  3,  4,  9,  10, 12, 13);
  -- constant pad3d : padding := (0, 16, 24, 4,  14, 10, 6,  22);

  -- DFT multiplication coeficient array
  -- type t_calc_vals_arr is array(0 to 31) of b25_real_array(0 to 7);

  -- DFT rotation reference
  -- type t_cos_val_ref is array(0 to 31) of natural range 0 to 8;
  -- constant cos_val_ref : t_cos_val_ref := (0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1); -- Assuming no DFT-IDFT inversion
  -- constant cos_sig_ref : t_cos_val_ref := (0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0);
  -- constant sin_sig_ref : t_cos_val_ref := (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

  -- DFT omega constants
  -- constant c_base : real := MATH_PI/16.0;
  -- constant w_cos1 : unsigned := to_unsigned(natural(65536.0*cos(1.0 * c_base)), 17);
  -- constant w_cos2 : unsigned := to_unsigned(natural(65536.0*cos(2.0 * c_base)), 17);
  -- constant w_cos3 : unsigned := to_unsigned(natural(65536.0*cos(3.0 * c_base)), 17);
  -- constant w_cos4 : unsigned := to_unsigned(natural(65536.0*cos(4.0 * c_base)), 17);
  -- constant w_cos5 : unsigned := to_unsigned(natural(65536.0*cos(5.0 * c_base)), 17);
  -- constant w_cos6 : unsigned := to_unsigned(natural(65536.0*cos(6.0 * c_base)), 17);
  -- constant w_cos7 : unsigned := to_unsigned(natural(65536.0*cos(7.0 * c_base)), 17);

  -- Flux Mul k-correction
  constant kcon   : real := 0.2239282404699562528386872156786372562;

  -- Pi constants for angle normalization
  constant pi24            : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**16)*MATH_PI)    ,24));
  constant two_pi24        : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**17)*MATH_PI)    ,24));
  constant half_pi24       : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**15)*MATH_PI)    ,24));
  constant three_half_pi24 : std_logic_vector(23 downto 0) := std_logic_vector(to_unsigned(natural((2.0**15)*3.0*MATH_PI),24));

  -- CORDIC arctangent LUT
  type t_arctan_lut is array (0 to 24) of std_logic_vector(23 downto 0);
  constant arctan_lut : t_arctan_lut := (
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -0.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -1.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -2.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -3.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -4.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -5.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -6.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -7.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -8.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** ( -9.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-10.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-11.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-12.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-13.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-14.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-15.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-16.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-17.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-18.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-19.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-20.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-21.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-22.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-23.0)))), 24)),
    std_logic_vector(to_unsigned(natural(65536.0*(arctan(2.0 ** (-24.0)))), 24))
  );

  

  -- Component declarations

  component b25_cmul is
    generic (
      con : std_logic_vector(24 downto 0)
    );
    port (
      a   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_wmul is
    generic (
      w : natural
    );
    port (
      i : in    b25_complex;
      o : out   b25_complex
    );
  end component b25_wmul;

  component b25_mul is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_add is
    port (
      a   : in    std_logic_vector(24 downto 0);
      b   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component;

  component b25_butterfly is
    port (
      i_top, i_bot : in    b25_complex;
      o_top, o_bot : out   b25_complex
    );
  end component b25_butterfly;

  component varshiftright is
    generic (
      len : natural := 8
    );
    port (
      data     : in    std_logic_vector(len - 1 downto 0);
      distance : in    std_logic_vector(integer(ceil(log2(real(len)))) - 1 downto 0);
      result   : out   std_logic_vector(len - 1 downto 0)
    );
  end component;

  component dft is
    port (
      i       : in    b25_real_array(0 to 7);
      o       : out   b25_complex_array(0 to 16);
      clock   : in    std_logic;
      start   : in    std_logic;
      reset   : in    std_logic;
      s_ready : out   std_logic
    );
  end component;

  component fft is
    port (
      i                   : in  b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      o                   : out b25_complex_array(0 to n_points/2);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component fft;

  component adder_carry is
    port (
      a   : in    std_logic_vector(49 downto 0);
      b   : in    std_logic_vector(49 downto 0);
      cin : in    std_logic;
      o   : out   std_logic_vector(49 downto 0)
    );
  end component;

  component cordic is
    generic (
      j_len      : natural := 5;
      coords_len : natural := 25
    );
    port (
      sigma_in  : in    std_logic;
      rotation  : in    std_logic;
      j         : in    std_logic_vector(j_len - 1 downto 0);
      x_in      : in    std_logic_vector(coords_len - 1 downto 0);
      y_in      : in    std_logic_vector(coords_len - 1 downto 0);
      z_in      : in    std_logic_vector(coords_len - 1 downto 0);
      x_out     : out   std_logic_vector(coords_len - 1 downto 0);
      y_out     : out   std_logic_vector(coords_len - 1 downto 0);
      z_out     : out   std_logic_vector(coords_len - 1 downto 0);
      sigma_out : out   std_logic
    );
  end component;

  component flux_inverter is
    port (
      clock    : in    std_logic;
      reset_s  : in    std_logic;
      reset_as : in    std_logic;
      load     : in    std_logic;
      inp      : in    std_logic_vector(23 downto 0);
      nex      : in    std_logic_vector(23 downto 0);
      outp     : out   std_logic_vector(23 downto 0);
      new_bit  : out   std_logic;
      ready    : out   std_logic;
      erro     : out   std_logic
    );
  end component;

  component flux_multiplier is
    generic (
      n_idx     : natural := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      run       : in    std_logic;
      run_coefs : in    std_logic;
      a         : in    std_logic_vector(23 downto 0);
      b         : in    std_logic_vector(23 downto 0);
      a_nex     : in    std_logic_vector(23 downto 0);
      b_nex     : in    std_logic_vector(23 downto 0);
      coefs_x   : out   b25_real_array(0 to n_points/4-1);
      coefs_y   : out   b25_real_array(0 to n_points/4-1);
      p         : out   std_logic_vector(24 downto 0);
      ready     : out   std_logic
    );
  end component;

  component hadamard_uc is
    port (
      clock, start, reset    : in     std_logic;
      mul_ready              : in     std_logic;
      cordic_mode, flux_mode : out    std_logic_vector(1 downto 0);
      rotation               : out    std_logic;
      ready                  : buffer std_logic
    );
  end component;

  component hadamard is
    generic (
      n_idx : natural := 0
    );
    port (
      clock     : in    std_logic;
      reset     : in    std_logic;
      start     : in    std_logic;
      x_i       : in    std_logic_vector(24 downto 0);
      y_i       : in    std_logic_vector(24 downto 0);
      x_k       : in    std_logic_vector(24 downto 0);
      y_k       : in    std_logic_vector(24 downto 0);
      p_coefs_x : out   b25_real_array(0 to n_points/4-1);
      p_coefs_y : out   b25_real_array(0 to n_points/4-1);
      ready     : buffer std_logic
    );
  end component;

  component hecate is
    port (
      img_transf          : in b25_complex_array(0 to n_points/2);
      ker_transf          : in b25_complex_array(0 to n_points/2);
      clock, reset, start : in std_logic;
      res                 : out b25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
      ready               : out std_logic
    );
  end component;

  component hecate_oa is
    port (
      img                 : in b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker                 : in b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clock, reset, start : in std_logic;
      res                 : out b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
      ready               : out std_logic := '0'
    );
  end component;

  component conv3d is
    port (
      img : in  b25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker : in  b25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clk : in  std_logic;
      rst : in  std_logic;
      run : in  std_logic;
      res : out b25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
      rdy : out std_logic
    );
  end component conv3d;








  -- Functions

  type integer_pair is array(0 to 1) of integer;
  type integer_trio is array(0 to 2) of integer;
  type integer_pair_array is array (natural range <>) of integer_pair;
  type integer_pair_2d_array is array (natural range <>) of integer_pair_array;
  type integer_trio_array is array (natural range <>) of integer_trio;
  type integer_trio_2d_array is array (natural range <>) of integer_trio_array;

  function scramble_lut(n : integer) return integer;
  function bfly_idx(s, n : integer) return integer_pair;
  function wmul_idx(s, n : integer) return integer_trio;
  function bfly_idx_rev(s, b, tb : integer) return integer;
  function wmul_idx_rev(s, w, m : integer) return integer;

  function twiddle (inp : natural) return b25_complex;
  function k_twiddle (inp : natural) return std_logic_vector;
  function w_add (a, b : std_logic_vector(24 downto 0)) return std_logic_vector;
  function idft_lut (n, w : integer) return boolean;

end package hecate_pkg;

package body hecate_pkg is
    
    -- "Scrambling" is the natural sorting process that an array undergoes when passing through a discrete fourier transform. By scrambling the array in the same manner before the operation, it will return the array in its original order
    function scramble_lut(n : integer) return integer is
      variable idx : integer := 0;
    begin
      for g in 0 to the_log-1 loop
        if (n mod (2**(g+1)) >= 2**g) then
          idx := idx + n_points / (2**(g+1));
        end if;
      end loop;
      return idx;
    end function;
  
    -- bfly_idx converts n to the order the butterflies are at, top to bottom, in their respective state
    function bfly_idx(s, n : integer) return integer_pair is
      constant b : integer := (n/(2**s)) * (2**(s-1)) + (n mod (2**(s-1))); -- bfly_pos = bfly_group*group_size + pos_in_group
      -- Yes, (n/(2**s)) * (2**(s-1)) = n/2, except NOT because rounding. Leave it like that, it's synth time
      constant tb : boolean := (n mod (2**s)) >= 2**(s-1);
    begin
      if ((s < 1) or (s > the_log)) then
        return (0,0);
      else
        --report "Inside bfly_idx: s = " & integer'image(s) & "   n = " & integer'image(n) & "   b = " & integer'image(b);
        if (tb) then
          return (b,1);
        else
          return (b,0);
        end if;
      end if;
    end function;
    
    -- wmul_idx converts n to the respective w multipliers, in their respective state, or returns (0,0,1) if no multiplication is needed
    function wmul_idx(s, n : integer) return integer_trio is
      constant valid : boolean := (n mod (2**(s+1))) >= 2**s; -- it's tb for the next state. I hate/love Fourier symmetry
      constant w : integer := (n mod (2**s)) * (2**(the_log-s-1)); -- pos_in_group (next state) times decreasing constant (2**(the_log-s-1))
      constant m : integer := n/(2**(s+1)) ; 
    begin
      if ((s < 1) or (s > the_log-1) or not valid) then
        return (0,0,0);
      else
        --if (n mod (2**s)) >= (2**(s-1)) then
          --return (w,m+1,0);
        --else
          return (w,m,1);
        --end if;
      end if;
    end function;
  
    -- bfly_idx_rev converts (b, tb) back to n, in their respective state
    function bfly_idx_rev(s, b, tb : integer) return integer is
      constant group_size   : integer := (2**(s-1));       -- [in BFLYS]
      constant pos_in_group : integer := b mod group_size; -- [in BFLYS]
      constant group_idx    : integer := b/group_size;
      constant n : integer := 2*group_size*group_idx + pos_in_group + group_size*tb;
    begin
      if ((s < 1) or (s > the_log)) then
        return 0;
      else
        return n;
      end if;
    end function;
  
    -- wmul_idx_rev converts (w, m) back to n, in its respective state
    function wmul_idx_rev(s, w, m : integer) return integer is
      constant group_size   : integer := (2**(s-1))*2;           -- [in POINTS]
      constant pos_in_group : integer := w / (2**(the_log-s-1)); -- [in POINTS]
      constant group_idx    : integer := 2*m+1;
      constant n : integer := group_size*group_idx + pos_in_group;
    begin
      if ((s < 1) or (s > the_log-1) or (n > n_points-1)) then -- or (n mod (2**(s+1)) < 2**s) (invalid)
        return 0;
      else
        return n;
      end if;
    end function;



    -- Generic twiddle function
    function twiddle (inp : natural) return b25_complex is
      constant base : real := 2.0*MATH_PI/real(n_points);
      variable x : b25_complex;
    begin
      if (inp > n_points/4) then
        x(0) := ('1', "0000000", std_logic_vector(to_unsigned(natural(65536.0*cos(real(n_points/2-inp) * base)), 17)));
      else
        x(0) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*cos(real(inp) * base)), 17)));
      end if;
      x(1) := ('0', "0000000", std_logic_vector(to_unsigned(natural(65536.0*sin(real(inp) * base)), 17)));
      return b25_complex(x);
    end function;

    -- K-corrected twiddle function
    function k_twiddle (inp : natural) return std_logic_vector is
      constant base : real := MATH_PI/real(n_points/2);
      variable x : std_logic_vector(24 downto 0);
    begin
      x := '0' & std_logic_vector(to_unsigned(natural(65536.0*(cos(real(inp) * base) * kcon)), 24));
      return x;
    end function;

    -- b25_add function (synth-time)
    function w_add (a, b : std_logic_vector(24 downto 0)) return std_logic_vector is
      variable temp_res   : std_logic_vector(23 downto 0) := (others => '0');
      variable temp_sign  : std_logic := '0';
      variable sa, sb, st : signed(23 downto 0);
    begin
      sa := signed(a(23 downto 0));
      sb := signed(b(23 downto 0));
      if ((a(24) xor b(24)) = '1') then
        st := sa - sb;
        if (st < 0) then
          temp_res  := std_logic_vector(-st);
          temp_sign := b(24);
        else
          temp_res  := std_logic_vector(st);
          temp_sign := a(24);
        end if;
      else
        temp_res  := std_logic_vector(sa + sb);
        temp_sign := a(24);
      end if;
      return (temp_sign & temp_res);
    end function;

    -- idft LUT for n_idx vs w (synth time)
    function idft_lut (n, w : integer) return boolean is
      variable valid_gen : boolean := false;
    begin
      for s in 1 to the_log-2 loop
        if (
          (w = 0) or (
            (n mod (2**s) = (2**(s-1))) and 
            (w mod (2**(s-1)) = 0)
          ) 
        ) then
          valid_gen := true;
        end if;
      end loop;
      return valid_gen;
    end function;

end package body hecate_pkg;

