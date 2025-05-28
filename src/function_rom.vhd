use work.hecate_pkg.all;

package function_rom is
  constant scramble_lut  : natural_array         (0 to n_points-1)                                      := build_scramble_idx;
  constant bfly_lut      : natural_pair_2d_array (1 to the_log)(0 to n_points-1)                        := build_bfly_idx;
  constant wmul_lut      : natural_trio_2d_array (1 to the_log-1)(0 to n_points-1)                      := build_wmul_idx;
  constant bfly_lut_rev  : natural_3d_array      (1 to the_log)(0 to n_points/2-1)(0 to 1)              := build_bfly_idx_rev;
  constant wmul_lut_rev  : natural_3d_array      (1 to the_log-1)(0 to n_points/2-1)(0 to n_points/4-1) := build_wmul_idx_rev;
  constant twiddle_lut   : b25_complex_array     (1 to n_points/2-1)                                    := build_twiddle;
  constant k_twiddle_lut : b25_real_array        (0 to n_points/4-1)                                    := build_k_twiddle;
  constant fft_nmul_lut  : bool_2d_array         (1 to n_points/2-1)(0 to n_points/4-1)                 := build_fft_nmul_idx;
  constant idft_nmul_lut : bool_2d_array         (0 to n_points-1)(0 to n_points/4-1)                   := build_idft_nmul_idx;
  constant w_add_lut     : b25_complex_array     (1 to n_points/2-1)                                    := build_w_add_synth;

  attribute rom_style of
    scramble_lut, bfly_lut, wmul_lut, bfly_lut_rev, wmul_lut_rev, twiddle_lut, k_twiddle_lut, fft_nmul_lut, idft_nmul_lut, w_add_lut
  : constant is "block";
end package function_rom;