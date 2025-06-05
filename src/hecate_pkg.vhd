library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

  -- Synth parameters
  attribute rom_style : string;

  -- Main parameters
  constant ix : natural := 2; -- assumes i mod k = 0, use assert in the testbench
  constant iy : natural := 2;
  constant iz : natural := 2;

  constant kx : natural := 2;
  constant ky : natural := 2;
  constant kz : natural := 2;

  constant ox : natural := (ix+kx-1);
  constant oy : natural := (iy+ky-1);
  constant oz : natural := (iz+kz-1);
  
  constant nx : natural := (2*kx-1);
  constant ny : natural := (2*ky-1);
  constant nz : natural := (2*kz-1);

  constant slice_x : natural := ix/kx;
  constant slice_y : natural := iy/ky;
  constant slice_z : natural := iz/kz;

  constant n_points_nopad : natural := nx*ny*nz;
  constant n_points       : natural := natural(2**ceil(log2(real(n_points_nopad))));
  constant the_log        : natural := natural(log2(real(n_points)));

  constant cordic_len     : natural := 25;
  constant cordic_len_log : natural := natural(ceil(log2(real(cordic_len))));

  attribute rom_style of 
    ix, iy, iz, kx, ky, kz, ox, oy, oz, nx, ny, nz, slice_x, slice_y, slice_z, n_points_nopad, n_points, the_log, cordic_len, cordic_len_log
  : constant is "block";

  -- Signed 25-bit types
  type s25_real_array is array (natural range <>) of signed(24 downto 0);
  type s25_double_array is array (natural range <>) of signed(49 downto 0);
  type s25_complex is array (0 to 1) of signed(24 downto 0);
  type s25_complex_array is array (natural range <>) of s25_complex;
  type s25_2d_real_array is array (natural range <>) of s25_real_array;
  type s25_3d_real_array is array (natural range <>) of s25_2d_real_array;
  type s25_2d_complex_array is array (natural range <>) of s25_complex_array;
  type s25_3d_complex_array is array (natural range <>) of s25_2d_complex_array;

  -- SLV 25-bit types
  type b25_real_array is array (natural range <>) of std_logic_vector(24 downto 0);
  type b25_double_array is array (natural range <>) of std_logic_vector(49 downto 0);
  type b25_complex is array (0 to 1) of std_logic_vector(24 downto 0);
  type b25_complex_array is array (natural range <>) of s25_complex;
  type b25_2d_real_array is array (natural range <>) of s25_real_array;
  type b25_3d_real_array is array (natural range <>) of s25_2d_real_array;
  type b25_2d_complex_array is array (natural range <>) of s25_complex_array;
  type b25_3d_complex_array is array (natural range <>) of s25_2d_complex_array;
  
  -- Hadamard state list
  type t_state is (initial, vector_flux, pre_rot, rot_kmul, final);


    -- Constants (ROM)

  -- Flux Mul k-correction
  constant kcon     : real := 0.2239282404699562528386872156786372562;
  constant b25_kcon : std_logic_vector(24 downto 0) := std_logic_vector(to_unsigned(natural((2.0**16)*(kcon)), 25));

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

  attribute rom_style of 
    kcon, b25_kcon, pi24, two_pi24, half_pi24, three_half_pi24, arctan_lut
  : constant is "block";








  -- Component declarations

  component b25_add is
    port (
      a   : in  std_logic_vector(24 downto 0);
      b   : in  std_logic_vector(24 downto 0);
      res : out std_logic_vector(24 downto 0)
    );
    end component;

  component b25_kmul is
    generic (
      con : std_logic_vector(24 downto 0)
    );
    port (
      a   : in    std_logic_vector(24 downto 0);
      res : out   std_logic_vector(24 downto 0)
    );
  end component b25_kmul;

  component s25_wmul is
    generic (
      w : natural
    );
    port (
      i : in  s25_complex;
      o : out s25_complex
    );
  end component s25_wmul;

  component s25_butterfly is
    port (
      i_top, i_bot : in  s25_complex;
      o_top, o_bot : out s25_complex
    );
  end component s25_butterfly;

  component var_srl is
    port (
      data     : in    std_logic_vector(24 downto 0);
      distance : in    unsigned(cordic_len_log-1 downto 0);
      result   : out   std_logic_vector(24 downto 0)
    );
  end component;

  component fft is
    port (
      i                   : in  s25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      o                   : out s25_complex_array(0 to n_points/2);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component;

  component ifft is
    port (
      i                   : in  s25_complex_array(0 to n_points/2);
      o                   : out s25_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component;

  component adder_carry is
    port (
      a, b: in    std_logic_vector(48 downto 0);
      cin : in    std_logic;
      o   : out   std_logic_vector(48 downto 0)
    );
  end component;

  component cordic is
    port (
      sigma_in  : in    std_logic := '0';
      rotation  : in    std_logic;
      j         : in    unsigned(cordic_len_log-1 downto 0);
      x_in      : in    std_logic_vector(24 downto 0);
      y_in      : in    std_logic_vector(24 downto 0);
      z_in      : in    std_logic_vector(24 downto 0);
      x_out     : out   std_logic_vector(24 downto 0);
      y_out     : out   std_logic_vector(24 downto 0);
      z_out     : out   std_logic_vector(24 downto 0);
      sigma_out : out   std_logic
    );
  end component;

  component flux_inverter is
    port (
      clock    : in    std_logic;
      reset_s  : in    std_logic;
      reset_as : in    std_logic;
      load     : in    std_logic;
      inp      : in    std_logic_vector(cordic_len-2 downto 0);
      nex      : in    std_logic_vector(cordic_len-2 downto 0);
      outp     : out   std_logic_vector(cordic_len-2 downto 0);
      new_bit  : out   std_logic;
      ready    : out   std_logic;
      erro     : out   std_logic
    );
  end component;

  component flux_multiplier is
    port (
      clock, reset, run  : in    std_logic;
      a, b, a_nex, b_nex : in    std_logic_vector(23 downto 0);
      p                  : out   std_logic_vector(24 downto 0);
      ready              : out   std_logic
    );
  end component;

  component hadamard_uc is
    port (
      clock, start, reset               : in  std_logic;
      polar_latch_ready, j_end          : in  std_logic;
      cordic_mode                       : out std_logic_vector(1 downto 0);
      ready, rotation, flux_run, kx_run : out std_logic
    );
  end component;

  component hadamard is
    port (
      clock : in  std_logic;
      reset : in  std_logic;
      start : in  std_logic;
      img   : in  s25_complex;
      ker   : in  s25_complex;
      p     : out s25_complex;
      ready : out std_logic
    );
  end component;

  component hecate is
    port (
      img_transf          : in  s25_complex_array(0 to n_points/2);
      ker_transf          : in  s25_complex_array(0 to n_points/2);
      clock, reset, start : in  std_logic;
      res                 : out s25_complex_array(0 to n_points/2);
      ready               : out std_logic
    );
  end component;

  component hecate_oa is
    port (
      img                 : in s25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker                 : in s25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clock, reset, start : in std_logic;
      res                 : out s25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
      ready               : out std_logic := '0';
      slice_ready         : out std_logic := '0'
    );
  end component;

  component conv3d is
    port (
      img : in  s25_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker : in  s25_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clk : in  std_logic;
      rst : in  std_logic;
      run : in  std_logic;
      res : out s25_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
      rdy : out std_logic
    );
  end component conv3d;








  -- Functions / LUTs

  type bool_array            is array (natural range <>) of boolean;
  type bool_2d_array         is array (natural range <>) of bool_array;
  type natural_array         is array (natural range <>) of natural;
  type natural_2d_array      is array (natural range <>) of natural_array;
  type natural_3d_array      is array (natural range <>) of natural_2d_array;
  type natural_pair          is array (0 to 1)           of natural;
  type natural_pair_array    is array (natural range <>) of natural_pair;
  type natural_pair_2d_array is array (natural range <>) of natural_pair_array;
  type natural_trio          is array (0 to 2)           of natural;
  type natural_trio_array    is array (natural range <>) of natural_trio;
  type natural_trio_2d_array is array (natural range <>) of natural_trio_array;

  function scramble_idx  (n        : natural) return natural;
  function bfly_idx      (s, n     : natural) return natural_pair;
  function wmul_idx      (s, n     : natural) return natural_trio;
  function bfly_idx_rev  (s, b, tb : natural) return natural;
  function wmul_idx_rev  (s, w, m  : natural) return natural;
  function twiddle       (inp      : natural) return s25_complex;
  function k_twiddle     (inp      : natural) return signed;
  function fft_nmul_idx  (w, m     : natural) return boolean;
  function idft_nmul_idx (n, w     : natural) return boolean;

  function build_scramble_idx  return natural_array;
  function build_bfly_idx      return natural_pair_2d_array;
  function build_wmul_idx      return natural_trio_2d_array;
  function build_bfly_idx_rev  return natural_3d_array;
  function build_wmul_idx_rev  return natural_3d_array;
  function build_twiddle       return s25_complex_array;
  function build_k_twiddle     return s25_real_array;
  function build_fft_nmul_idx  return bool_2d_array;
  function build_idft_nmul_idx return bool_2d_array;
  function build_w_add_synth   return s25_complex_array;

end package hecate_pkg;

package body hecate_pkg is

  -- "Scrambling" is the sorting process that an array naturally undergoes when passing through a discrete fourier transform. By scrambling the array in the same manner before the operation, we can return the array to its original ordering
  function scramble_idx(n : natural) return natural is
    variable idx : natural := 0;
  begin
    for g in 0 to the_log-1 loop
      if (n mod (2**(g+1)) >= 2**g) then
        idx := idx + n_points / (2**(g+1));
      end if;
    end loop;
    return idx;
  end function;

  -- bfly_idx converts n to the order the butterflies are at, top to bottom, in their respective state
  function bfly_idx(s, n : natural) return natural_pair is
    constant b : natural := (n/(2**s)) * (2**(s-1)) + (n mod (2**(s-1))); -- bfly_pos = bfly_group*group_size + pos_in_group
    -- Yes, (n/(2**s)) * (2**(s-1)) = n/2, except NOT because rounding. Leave it like that, it's synth time
    constant tb : boolean := (n mod (2**s)) >= 2**(s-1);
  begin
    if ((s < 1) or (s > the_log)) then
      return (0,0);
    else
      --report "Inside bfly_idx: s = " & natural'image(s) & "   n = " & natural'image(n) & "   b = " & natural'image(b);
      if (tb) then
        return (b,1);
      else
        return (b,0);
      end if;
    end if;
  end function;
  
  -- wmul_idx converts n to the respective w multipliers, in their respective state, or returns (0,0,1) if no multiplication is needed
  function wmul_idx(s, n : natural) return natural_trio is
    constant valid : boolean := (n mod (2**(s+1))) >= 2**s; -- it's tb for the next state. I hate/love Fourier symmetry
    constant w : natural := (n mod (2**s)) * (2**(the_log-s-1)); -- pos_in_group (next state) times decreasing constant (2**(the_log-s-1))
    constant m : natural := n/(2**(s+1)) ; 
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
  function bfly_idx_rev(s, b, tb : natural) return natural is
    constant group_size   : natural := (2**(s-1));       -- [in BFLYS]
    constant pos_in_group : natural := b mod group_size; -- [in BFLYS]
    constant group_idx    : natural := b/group_size;
    constant n : natural := 2*group_size*group_idx + pos_in_group + group_size*tb;
  begin
    if ((s < 1) or (s > the_log)) then
      return 0;
    else
      return n;
    end if;
  end function;

  -- wmul_idx_rev converts (w, m) back to n, in its respective state
  function wmul_idx_rev(s, w, m : natural) return natural is
    constant group_size   : natural := (2**(s-1))*2;           -- [in POINTS]
    constant pos_in_group : natural := w / (2**(the_log-s-1)); -- [in POINTS]
    constant group_idx    : natural := 2*m+1;
    constant n : natural := group_size*group_idx + pos_in_group;
  begin
    if ((s < 1) or (s > the_log-1) or (n > n_points-1)) then -- or (n mod (2**(s+1)) < 2**s) (invalid)
      return 0;
    else
      return n;
    end if;
  end function;

  -- Generic twiddle function
  function twiddle (inp : natural) return s25_complex is
    constant base : real := 2.0*MATH_PI/real(n_points);
    variable x : s25_complex;
  begin
    x(0) := to_signed(integer((2.0**16)*cos(real(inp) * base)), 25);
    x(1) := to_signed(integer((2.0**16)*sin(real(inp) * base)), 25);
    return s25_complex(x);
  end function;

  -- K-corrected twiddle function
  function k_twiddle (inp : natural) return signed is
    constant base : real := MATH_PI/real(n_points/2);
    variable x : signed(24 downto 0);
  begin
    x := to_signed(natural((2.0**16)*(cos(real(inp) * base) * kcon)), 25);
    return x;
  end function;

  -- fft LUT for w vs m (synth time)
  function fft_nmul_idx (w, m : natural) return boolean is
    variable valid_gen : boolean := false;
  begin
    for s in 0 to the_log-2 loop
      if ((w mod (2**s) = 0) and (m < 2**s)) then
        valid_gen := true;
      end if;
    end loop;
    return valid_gen;
  end function;

  -- idft LUT for n_idx vs w (synth time)
  function idft_nmul_idx (n, w : natural) return boolean is
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








  -- ROM Builders

  function build_scramble_idx return natural_array is
    variable res : natural_array(0 to n_points-1);
  begin
    for n in 0 to n_points-1 loop
      res(n) := scramble_idx(n);
    end loop;
    return res;
  end function build_scramble_idx;

  function build_bfly_idx return natural_pair_2d_array is
    variable res : natural_pair_2d_array(1 to the_log)(0 to n_points-1);
  begin
    for s in 1 to the_log loop
      for n in 0 to n_points-1 loop
        res(s)(n) := bfly_idx(s,n);
      end loop;
    end loop;
    return res;
  end function build_bfly_idx;

  function build_wmul_idx return natural_trio_2d_array is
    variable res : natural_trio_2d_array(1 to the_log-1)(0 to n_points-1);
  begin
    for s in 1 to the_log-1 loop
      for n in 0 to n_points-1 loop
        res(s)(n) := wmul_idx(s,n);
      end loop;
    end loop;
    return res;
  end function build_wmul_idx;

  function build_bfly_idx_rev return natural_3d_array is
    variable res : natural_3d_array(1 to the_log)(0 to n_points/2-1)(0 to 1);
  begin
    for s in 1 to the_log loop
      for b in 0 to n_points/2-1 loop
        for tb in 0 to 1 loop
          res(s)(b)(tb) := bfly_idx_rev(s,b,tb);
        end loop;
      end loop;
    end loop;
    return res;
  end function build_bfly_idx_rev;

  function build_wmul_idx_rev return natural_3d_array is
    variable res : natural_3d_array(1 to the_log-1)(0 to n_points/2-1)(0 to n_points/4-1);
  begin
    for s in 1 to the_log-1 loop
      for w in 0 to n_points/2-1 loop
        for m in 0 to n_points/4-1 loop
          res(s)(w)(m) := wmul_idx_rev(s,w,m);
        end loop;
      end loop;
    end loop;
    return res;
  end function build_wmul_idx_rev;

  function build_twiddle return s25_complex_array is
    variable res : s25_complex_array(1 to n_points-1);
  begin
    for n in 1 to n_points-1 loop
      res(n) := twiddle(n);
    end loop;
    return res;
  end function build_twiddle;

  function build_k_twiddle return s25_real_array is
    variable res : s25_real_array(0 to n_points/4-1);
  begin
    for n in 0 to n_points/4-1 loop
      res(n) := k_twiddle(n);
    end loop;
    return res;
  end function build_k_twiddle;

  function build_fft_nmul_idx return bool_2d_array is
    variable res : bool_2d_array(1 to n_points/2-1)(0 to n_points/8-1);
  begin
    for w in 1 to n_points/2-1 loop
      for m in 0 to n_points/8-1 loop
        res(w)(m) := fft_nmul_idx(w,m);
      end loop;
    end loop;
    return res;
  end function build_fft_nmul_idx;

  function build_idft_nmul_idx return bool_2d_array is
    variable res : bool_2d_array(0 to n_points-1)(0 to n_points/4-1);
  begin
    for n in 0 to n_points-1 loop
      for w in 0 to n_points/4-1 loop
        res(n)(w) := idft_nmul_idx(n,w);
      end loop;
    end loop;
    return res;
  end function build_idft_nmul_idx;

  function build_w_add_synth return s25_complex_array is
    variable res : s25_complex_array(1 to n_points-1);
  begin
    for w in 1 to n_points-1 loop
      res(w)(0) := twiddle(w)(0) + twiddle(w)(1); -- c+d
      res(w)(1) := twiddle(w)(1) - twiddle(w)(0); -- d-c
    end loop;
    return res;
  end function build_w_add_synth;

end package body hecate_pkg;