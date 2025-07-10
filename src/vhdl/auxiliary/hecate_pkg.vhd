library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package hecate_pkg is

    --=================--
    -- Main Parameters --
    --=================--

    constant ix : natural := 4; -- C3D net-64 padded = 66
    constant iy : natural := 4;
    constant iz : natural := 4; -- RGB frame inputs = 3
  
    constant kx : natural := 2;
    constant ky : natural := 2;
    constant kz : natural := 2;
    constant kn : natural := 1; -- C3D first conv layer = 64

    constant signed_size  : natural := 32; -- number of bits in signed signals 
    constant signed_point : natural := 24; -- number of bits past the point 
    constant pfb_size     : natural := 24; -- number of bits in pi-factor binary

    constant test_n       : natural  := 2;
    constant test_seed1   : positive := 3928;
    constant test_seed2   : positive := 11;




  --==================--
  -- Type Definitions -- 
  --==================--

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
  
  -- State machine lists
  type t_had_state       is (initial, vector_mul, pre_rot, rot_kmul, final);
  type t_hec_state       is (initial, ker_fft, latch_ker, slice_fft, had, latch_had, ifft, accumulate, hold, sl_reset);
  type t_vivado_tb_state is (initial, serial_in, conv_slice, serial_out, final);





  --=================--
  -- Constants (ROM) -- 
  --=================--

  -- Derived parameters

  constant ox : natural := (ix+kx-1);
  constant oy : natural := (iy+ky-1);
  constant oz : natural := (iz+kz-1);
  
  constant nx : natural := (2*kx-1);
  constant ny : natural := (2*ky-1);
  constant nz : natural := (2*kz-1);

  constant sx : natural := ix/kx;
  constant sy : natural := iy/ky;
  constant sz : natural := iz/kz;

  constant n_points_nopad : natural := nx*ny*nz;
  constant n_points       : natural := natural(2**ceil(log2(real(n_points_nopad))));
  constant the_log        : natural := natural(log2(real(n_points)));

  -- CORDIC k-correction -> (Product[Sqrt[1+2^(-2x)],{x,0,signed_point-1}])^-3
  constant kcon : real := 0.22392824057423056779858936992391541750457092029889299944181236773520544649;

  -- Signed constants
  constant signed_zero : t_signed := (others => '0');
  constant signed_one  : t_signed := (signed_point => '1', others => '0');
  constant signed_half : t_signed := (signed_point-1 => '1', others => '0');
  constant signed_kcon : t_signed := to_signed(natural((2.0**signed_point)*(kcon)), signed_size);

  -- Set ROM style
  attribute rom_style : string;
  attribute rom_style of 
    ix, iy, iz, kx, ky, kz,
    signed_size, signed_point, pfb_size,
    test_seed1, test_seed2, test_n,
    ox, oy, oz, nx, ny, nz, sx, sy, sz, n_points_nopad, n_points, the_log,
    signed_kcon, signed_zero, signed_one, signed_half
  : constant is "block";




  --========================--
  -- Component Declarations --
  --========================--

  component butterfly is
    port (
      i_top, i_bot : in  t_signed_complex;
      o_top, o_bot : out t_signed_complex
    );
  end component butterfly;

  component wmul is
    port (
      i : in  t_signed_complex;
      w : in  natural;
      s : in  std_logic;
      o : out t_signed_complex
    );
  end component wmul;

  component fft is
    port (
      i                   : in  t_signed_complex_array(0 to n_points-1);
      o                   : out t_signed_complex_array(0 to n_points-1);
      clock, reset, start : in  std_logic;
      clockwise           : in  std_logic;
      s_ready             : out std_logic
    );
  end component;

  component pfb_qadd is
    port (
      ax, ay, bx, by : in  t_signed;
      az0, bz0       : in  t_pfb;
      sz0            : out t_pfb;
      sxs, sys       : out std_logic 
    );
  end component pfb_qadd;

  component cordic is
    port (
      j                   : in  integer range 0 to signed_size;
      sigma_in, rotation  : in  std_logic;
      x_in, y_in          : in  t_signed;
      z_in                : in  t_pfb;
      sigma_out, comp_out : out std_logic;
      x_out, y_out        : out t_signed;
      z_out               : out t_pfb
    );
  end component;

  component hadamard_cu is
    port (
      clock, start, reset      : in  std_logic;
      polar_latch_ready, j_end : in  std_logic;
      cordic_mode              : out std_logic_vector(1 downto 0);
      ready, rotation          : out std_logic
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
      slice, ker          : in  t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
      clock, reset, start : in  std_logic;
      sxi, syi, szi       : in  natural;
      ker_ready           : out std_logic;
      acc_ready           : out std_logic;
      res                 : out t_signed_3d_real_array(0 to oz-1)(0 to oy-1)(0 to ox-1)
    );
  end component;




  --=======================--
  -- Function Declarations --
  --=======================--

  type t_natural_array    is array (natural range <>)   of natural;
  type t_natural_2d_array is array (natural range <>)   of t_natural_array;
  type t_pfb_array        is array (0 to signed_size-1) of t_pfb;
  type t_pfb_array_sign   is array (0 to 1) of t_pfb_array; -- 0 = positive; 1 = negative

  function kernel_f                         return t_signed_3d_real_array;
  function scramble_f    (n      : natural) return natural;
  function fft_net_f     (n, l   : natural) return natural;
  function fft_w_f       (n, l   : natural) return natural;
  function twiddle_f     (inp, s : natural) return t_signed_complex;
  function twiddle_add_f (inp, s : natural) return t_signed_complex;
  function arctan_f      (j, s   : natural) return t_pfb;

  function build_scramble    return t_natural_array;
  function build_fft_net     return t_natural_2d_array;
  function build_fft_w       return t_natural_2d_array;
  function build_twiddle     return t_signed_2d_complex_array;
  function build_twiddle_add return t_signed_2d_complex_array;
  function build_arctan      return t_pfb_array_sign;

end package hecate_pkg;

package body hecate_pkg is

  --=======================--
  -- Function Descriptions --
  --=======================--

  function kernel_f return t_signed_3d_real_array is
    variable ker   : t_signed_3d_real_array(0 to kz-1)(0 to ky-1)(0 to kx-1);
    variable r     : real;
    variable seed1 : positive := 234;
    variable seed2 : positive := 678;
  begin
    -- TEMP - for simulation
    for z in 0 to kz-1 loop
      for y in 0 to ky-1 loop
        for x in 0 to kx-1 loop
          uniform(seed1, seed2, r);
          ker(z)(y)(x) := to_signed(integer(floor(r * (2.0**signed_point))), signed_size);
        end loop;
      end loop;
    end loop;
    return ker;
  end function;

  -- "Scrambling" is the sorting process that an array automatically undergoes when passing through a discrete fourier transform. By scrambling the array in the same manner before the operation, we can return the array to its original ordering
  function scramble_f(n : natural) return natural is
    variable idx : natural := 0;
  begin
    for g in 0 to the_log-1 loop
      if (n mod (2**(g+1)) >= 2**g) then
        idx := idx + n_points / (2**(g+1));
      end if;
    end loop;
    return idx;
  end function;

  -- tracing last transition   -- switch bit 0 and bit l     -- 3210 -> 0213
  function fft_net_f(n, l : natural) return natural is
    variable net   : natural;
    variable n_slv : unsigned(the_log-1 downto 0) := to_unsigned(n, the_log);
    variable temp_bit_l, temp_bit_0 : std_logic;
  begin
    if (l < the_log) then  
      temp_bit_l := n_slv(l);
      temp_bit_0 := n_slv(0);
      n_slv(0) := temp_bit_l;
      n_slv(l) := temp_bit_0;
      net := natural(to_integer(n_slv));
    else
      if (n < n_points/2) then
        net := 2*n;
      else
        net := 2*(n-n_points/2)+1;
      end if;
    end if;
    return net;
  end function;

  function fft_w_f(n, l : natural) return natural is
    variable w : natural;
    constant valid : boolean := (n mod 2) = 1;
  begin
    if valid then
      w := ((n/2) mod (2**l)) * (2**(the_log-l-1));
    else
      w := 0;
    end if;
    return w;
  end function;

  -- Generic twiddle function
  function twiddle_f(inp, s: natural) return t_signed_complex is
    constant base : real := 2.0*MATH_PI/real(n_points);
    variable x : t_signed_complex;
  begin
    x(0) := to_signed(integer((2.0**signed_point)*cos(real(inp) * base)), signed_size);
    x(1) := to_signed(integer((2.0**signed_point)*sin(real(inp) * base)), signed_size)
      when s=0
    else -to_signed(integer((2.0**signed_point)*sin(real(inp) * base)), signed_size);
    return t_signed_complex(x);
  end function;

  -- Twiddle addition function (for karatsuba)
  function twiddle_add_f (inp, s : natural) return t_signed_complex is
    variable x : t_signed_complex;
  begin
      x(0) := twiddle_f(inp, s)(0) + twiddle_f(inp, s)(1); -- c+d
      x(1) := twiddle_f(inp, s)(1) - twiddle_f(inp, s)(0); -- d-c
    return x;
  end function;

  -- CORDIC arctangent
  function arctan_f(j, s: natural) return t_pfb is
    variable res : t_pfb;
  begin
    res := to_signed(integer((2.0**pfb_size)*(arctan(2.0**(-real(j))))/(2.0*MATH_PI)), pfb_size)
      when s=0
    else -to_signed(integer((2.0**pfb_size)*(arctan(2.0**(-real(j))))/(2.0*MATH_PI)), pfb_size);
    return res;
  end function;




  --==============--
  -- ROM Builders --
  --==============--

  function build_scramble return t_natural_array is
    variable res : t_natural_array(0 to n_points-1);
  begin
    for n in 0 to n_points-1 loop
      res(n) := scramble_f(n);
    end loop;
    return res;
  end function build_scramble;

  function build_fft_net  return t_natural_2d_array is
    variable res : t_natural_2d_array(0 to n_points-1)(0 to the_log);
  begin
    for n in 0 to n_points-1 loop
      for l in 0 to the_log loop
        res(n)(l) := fft_net_f(n,l);
      end loop;
    end loop;
    return res;
  end function build_fft_net;

  function build_fft_w return t_natural_2d_array is
    variable res : t_natural_2d_array(0 to n_points-1)(0 to the_log-1);
  begin
    for n in 0 to n_points-1 loop
      for l in 0 to the_log-1 loop
        res(n)(l) := fft_w_f(n,l);
      end loop;
    end loop;
    return res;
  end function build_fft_w;

  function build_twiddle return t_signed_2d_complex_array is
    variable res : t_signed_2d_complex_array (0 to n_points-1)(0 to 1);
  begin
    for n in 0 to n_points-1 loop
      res(n)(0) := twiddle_f(n,0);
      res(n)(1) := twiddle_f(n,1);
    end loop;
    return res;
  end function build_twiddle;

  function build_twiddle_add return t_signed_2d_complex_array is
    variable res : t_signed_2d_complex_array(0 to n_points-1)(0 to 1);
  begin
    for n in 0 to n_points-1 loop
      res(n)(0) := twiddle_add_f(n,0);
      res(n)(1) := twiddle_add_f(n,1);
    end loop;
    return res;
  end function build_twiddle_add;

  function build_arctan return t_pfb_array_sign is
    variable res : t_pfb_array_sign;
  begin
    for j in 0 to signed_size-1 loop
      for s in 0 to 1 loop
        res(s)(j) := arctan_f(j,s);
      end loop;
    end loop;
    return res;
  end function build_arctan;


end package body hecate_pkg;