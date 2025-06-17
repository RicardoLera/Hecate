use work.hecate_pkg.all;

package function_rom is
  constant scramble_lut    : t_natural_array           (0 to n_points-1)                 := build_scramble;
  constant fft_net_lut     : t_natural_2d_array        (0 to n_points-1)(0 to the_log)   := build_fft_net;
  constant fft_w_lut       : t_natural_2d_array        (0 to n_points-1)(0 to the_log-1) := build_fft_w;
  constant twiddle_lut     : t_signed_complex_array    (0 to n_points-1)                 := build_twiddle;
  constant twiddle_add_lut : t_signed_2d_complex_array (0 to n_points-1)(0 to 1)         := build_twiddle_add;
  constant arctan_lut      : t_pfb_array_sign                                            := build_arctan;

  attribute rom_style of
    scramble_lut, fft_net_lut, fft_w_lut, twiddle_lut, arctan_lut
  : constant is "block";
end package function_rom;