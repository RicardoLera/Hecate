library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

  --==================--
  -- Type Definitions -- 
  --==================--

  -- Type parameters
  constant signed_size  : natural := 32; -- number of bits in signed signals 
  constant signed_point : natural := 24; -- number of bits past the point 
  constant pfb_size     : natural := 24; -- number of bits in pi-factor binary

  -- Subtypes
  subtype t_signed is signed(signed_size-1 downto 0);
  subtype t_pfb    is signed(pfb_size-1 downto 0);

  -- Signed types
  type t_signed_complex          is array (0 to 1)           of t_signed;
  type t_signed_real_array       is array (natural range <>) of t_signed;
  type t_signed_2d_real_array    is array (natural range <>) of t_signed_real_array;
  type t_signed_3d_real_array    is array (natural range <>) of t_signed_2d_real_array;
  type t_signed_complex_array    is array (natural range <>) of t_signed_complex;
  type t_signed_2d_complex_array is array (natural range <>) of t_signed_complex_array;
  type t_signed_3d_complex_array is array (natural range <>) of t_signed_2d_complex_array;
  
  -- Hadamard state machine list
  type t_state is (initial, vector_flux, pre_rot, rot_kmul, final);

  -- Function types
  type bool_array            is array (natural range <>)   of boolean;
  type bool_2d_array         is array (natural range <>)   of bool_array;
  type natural_array         is array (natural range <>)   of natural;
  type natural_2d_array      is array (natural range <>)   of natural_array;
  type natural_3d_array      is array (natural range <>)   of natural_2d_array;
  type natural_pair          is array (0 to 1)             of natural;
  type natural_pair_array    is array (natural range <>)   of natural_pair;
  type natural_pair_2d_array is array (natural range <>)   of natural_pair_array;
  type natural_trio          is array (0 to 2)             of natural;
  type natural_trio_array    is array (natural range <>)   of natural_trio;
  type natural_trio_2d_array is array (natural range <>)   of natural_trio_array;
  type t_pfb_array           is array (0 to signed_size-1) of t_pfb;
  type t_pfb_array_signed    is array (0 to 1)             of t_pfb_array; -- 0 is positive, 1 is negative




  --=================--
  -- Constants (ROM) -- 
  --=================--

  -- Main parameters
  constant ix : natural := 2; -- assumes i mod k = 0, use assert in the testbench
  constant iy : natural := 2;
  constant iz : natural := 2;

  constant kx : natural := 2;
  constant ky : natural := 2;
  constant kz : natural := 2;

  constant test_n     : natural  := 16;
  constant test_seed1 : positive := 3928;
  constant test_seed2 : positive := 11;

  constant cordic_len : natural := 20;

  -- Derived parameters

  constant signed_zero  : signed(signed_size-1 downto 0) := (others => '0');

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

  constant cordic_len_log : natural := natural(ceil(log2(real(cordic_len))));

  -- CORDIC k-correction -> (Product[Sqrt[1+2^(-2x)],{x,0,signed_point-1}])^-3
  constant kcon : real := 0.22392824057423056779858936992391541750457092029889299944181236773520544649;
  constant signed_kcon : t_signed := to_signed(natural((2.0**signed_point)*(kcon)), signed_size);

  -- Set ROM style
  attribute rom_style : string;
  attribute rom_style of 
    ix, iy, iz, kx, ky, kz, ox, oy, oz, nx, ny, nz, slice_x, slice_y, slice_z, n_points_nopad, n_points, the_log, cordic_len, cordic_len_log, test_seed1, test_seed2, test_n, kcon, signed_kcon
  : constant is "block";




  --=============================--
  -- Function & LUT Declarations --
  --=============================--

  function scramble_idx  (n        : natural) return natural;
  function bfly_idx      (s, n     : natural) return natural_pair;
  function wmul_idx      (s, n     : natural) return natural_trio;
  function bfly_idx_rev  (s, b, tb : natural) return natural;
  function wmul_idx_rev  (s, w, m  : natural) return natural;
  function twiddle       (inp      : natural) return t_signed_complex;
  function fft_nmul_idx  (w, m     : natural) return boolean;
  function idft_nmul_idx (n, w     : natural) return boolean;
  function cordic_arctan (j, s     : natural) return t_pfb;

  function build_scramble_idx  return natural_array;
  function build_bfly_idx      return natural_pair_2d_array;
  function build_wmul_idx      return natural_trio_2d_array;
  function build_bfly_idx_rev  return natural_3d_array;
  function build_wmul_idx_rev  return natural_3d_array;
  function build_twiddle       return t_signed_complex_array;
  function build_fft_nmul_idx  return bool_2d_array;
  function build_idft_nmul_idx return bool_2d_array;
  function build_cordic_arctan return t_pfb_array_signed;




  --========================--
  -- Component Declarations --
  --========================--

  component t_signed_butterfly is
    port (
      i_top, i_bot : in  t_signed_complex;
      o_top, o_bot : out t_signed_complex
    );
  end component t_signed_butterfly;

  component t_signed_wmul is
    generic (
      w : natural
    );
    port (
      i : in  t_signed_complex;
      o : out t_signed_complex
    );
  end component t_signed_wmul;

  component fft is
    port (
      i                   : in  t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      o                   : out t_signed_complex_array(0 to n_points/2);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component;

  component ifft is
    port (
      i                   : in  t_signed_complex_array(0 to n_points/2);
      o                   : out t_signed_3d_real_array(0 to nz-1)(0 to ny-1)(0 to nx-1);
      clock, reset, start : in  std_logic;
      s_ready             : out std_logic
    );
  end component;

  component pfb_q is
    port (
      a   : in t_pfb;
      qt  : in signed(1 downto 0);
      res : out t_pfb
    );
  end component pfb_q;

  component cordic is
    port (
      j                  : in  integer range 0 to cordic_len;
      sigma_in, rotation : in  std_logic;
      sigma_out          : out std_logic;
      x_in, y_in         : in  t_signed;
      x_out, y_out       : out t_signed;
      z_in               : in  t_pfb;
      z_out              : out t_pfb
    );
  end component;

  component flux_inverter is
    port (
      clock, reset_s, load : in  std_logic;
      new_bit, ready, err  : out std_logic;
      inp, nex             : in  unsigned(cordic_len-2 downto 0);
      outp                 : out unsigned(cordic_len-2 downto 0)
    );
  end component;

  component flux_multiplier is
    port (
      clock, reset, run  : in  std_logic;
      a, b, a_nex, b_nex : in  t_signed;
      p                  : out t_signed;
      ready              : out std_logic
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
      clock, reset, start : in  std_logic;
      img, ker            : in  t_signed_complex;
      p                   : out t_signed_complex;
      ready               : out std_logic
    );
  end component;

  component hadamard_arr is
    port (
      img_transf, ker_transf : in  t_signed_complex_array(0 to n_points/2);
      clock, reset, start    : in  std_logic;
      res                    : out t_signed_complex_array(0 to n_points/2);
      ready                  : out std_logic
    );
  end component;

  component conv3d is
    port (
      img : in  t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker : in  t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clk : in  std_logic;
      rst : in  std_logic;
      run : in  std_logic;
      res : out t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1);
      rdy : out std_logic
    );
  end component conv3d;

  component hecate is
    port (
      img                 : in t_signed_3d_real_array(0 to iz-1)(0 to iy-1)(0 to ix-1);
      ker                 : in t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clock, reset, start : in std_logic;
      res                 : out t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1) := (others => (others => (others => (others => '0'))));
      ready               : out std_logic := '0';
      ker_ready           : out std_logic := '0';
      slice_ready         : out std_logic := '0'
    );
  end component;

end package hecate_pkg;




package body hecate_pkg is

  --=======================--
  -- Function Descriptions --
  --=======================--

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
  function twiddle (inp : natural) return t_signed_complex is
    constant base : real := 2.0*MATH_PI/real(n_points);
    variable x : t_signed_complex;
  begin
    x(0) := to_signed(integer((2.0**signed_point)*cos(real(inp) * base)), signed_size);
    x(1) := to_signed(integer((2.0**signed_point)*sin(real(inp) * base)), signed_size);
    return t_signed_complex(x);
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

  -- CORDIC arctangent
  function cordic_arctan (j, s: natural) return t_pfb is
    variable res : t_pfb;
  begin
    res := to_signed(natural((2.0**signed_point)*(arctan(2.0**(-real(j))))/(2.0*MATH_PI)), pfb_size)
      when s=0
    else -to_signed(natural((2.0**signed_point)*(arctan(2.0**(-real(j))))/(2.0*MATH_PI)), pfb_size);
    return res;
  end function;




  --==============--
  -- ROM Builders --
  --==============--

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

  function build_twiddle return t_signed_complex_array is
    variable res : t_signed_complex_array(1 to n_points-1);
  begin
    for n in 1 to n_points-1 loop
      res(n) := twiddle(n);
    end loop;
    return res;
  end function build_twiddle;

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

  function build_cordic_arctan return t_pfb_array_signed is
    variable res : t_pfb_array_signed;
  begin
    for j in 0 to signed_size-1 loop
      for s in 0 to 1 loop
        res(s)(j) := cordic_arctan(j,s);
      end loop;
    end loop;
    return res;
  end function build_cordic_arctan;

end package body hecate_pkg;