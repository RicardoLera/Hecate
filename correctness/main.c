#include <inttypes.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "var.h"
#include "operations.h"

// We'll make N = 32 because that's the lowest power of two necessary to define 3d convolution
// Current error up to last 7 bits on worst case

// WARNING: doesn't compile with clang for some reason, only gcc

# define M_PI 3.14159265358979323846

// archvar twiddle_arr[16][2] = {
//   {{0, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^0 = e^0              = + cos(0pi/8) + 0           = + 1      + 0
//   {{0, 0x00, 0xec84}, {0, 0x00, 0x61f8}}, // w^1 = e^(2pi*i/16)     = + cos(pi/8)  + sin(pi/8)i  ~ + 0.ec84 + 0.61f8 i
//   {{0, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^2 = e^(2*(2pi*i/16)) = + cos(2pi/8) + sin(2pi/8)i ~ + 0.b505 + 0.b505 i
//   {{0, 0x00, 0x61f8}, {0, 0x00, 0xec84}}, // w^3 = e^(3*(2pi*i/16)) = + cos(3pi/8) + sin(3pi/8)i ~ + 0.61f8 + 0.ec84 i
//   {{0, 0x00, 0x0000}, {0, 0x01, 0x0000}}, // w^4 = e^(4*(2pi*i/16)) = 0            + sin(4pi/8)  = + 0      + i
//   {{1, 0x00, 0x61f8}, {0, 0x00, 0xec84}}, // w^5 = e^(5*(2pi*i/16)) = - cos(5pi/8) + sin(5pi/8)i ~ - 0.61f8 + 0.ec84 i
//   {{1, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^6 = e^(6*(2pi*i/16)) = - cos(6pi/8) + sin(6pi/8)i ~ - 0.b505 + 0.b505 i
//   {{1, 0x00, 0xec84}, {0, 0x00, 0x61f8}}, // w^7 = e^(7*(2pi*i/16)) = - cos(7pi/8) + sin(7pi/8)i ~ - 0.ec84 + 0.61f8 i

//   {{1, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^8  = -w^0 = - 1      + 0
//   {{1, 0x00, 0xec84}, {1, 0x00, 0x61f8}}, // w^9  = -w^1 ~ - 0.ec84 - 0.61f8 i
//   {{1, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^10 = -w^2 ~ - 0.b505 - 0.b505 i
//   {{1, 0x00, 0x61f8}, {1, 0x00, 0xec84}}, // w^11 = -w^3 ~ - 0.61f8 - 0.ec84 i
//   {{0, 0x00, 0x0000}, {1, 0x01, 0x0000}}, // w^12 = -w^4 = + 0      - i
//   {{0, 0x00, 0x61f8}, {1, 0x00, 0xec84}}, // w^13 = -w^5 ~ + 0.61f8 - 0.ec84 i
//   {{0, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^14 = -w^6 ~ + 0.b505 - 0.b505 i
//   {{0, 0x00, 0xec84}, {1, 0x00, 0x61f8}}  // w^15 = -w^7 ~ + 0.ec84 - 0.61f8 i
// };

archvar twiddle_arr[32][2] = {            // w^i  = e^(i@) ; @ = 2pi/N = pi/16

  {{0, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^0  = + cos(0@) + sin(0@)i = + 1.0000 + 0.0000 i

  {{0, 0x00, 0xfb15}, {0, 0x00, 0x31f1}}, // w^1  = + cos(1@) + sin(1@)i ~ + 0.fb15 + 0.31f1 i
  {{0, 0x00, 0xec83}, {0, 0x00, 0x61f8}}, // w^2  = + cos(2@) + sin(2@)i ~ + 0.ec83 + 0.61f8 i
  {{0, 0x00, 0xd4db}, {0, 0x00, 0x8e3a}}, // w^3  = + cos(3@) + sin(3@)i ~ + 0.d4db + 0.8e3a i
  {{0, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^4  = + cos(4@) + sin(4@)i ~ + 0.b505 + 0.b505 i
  {{0, 0x00, 0x8e3a}, {0, 0x00, 0xd4db}}, // w^5  = + cos(5@) + sin(5@)i ~ + 0.8e3a + 0.d4db i
  {{0, 0x00, 0x61f8}, {0, 0x00, 0xec83}}, // w^6  = + cos(6@) + sin(6@)i ~ + 0.61f8 + 0.ec83 i
  {{0, 0x00, 0x31f1}, {0, 0x00, 0xfb15}}, // w^7  = + cos(7@) + sin(7@)i ~ + 0.31f1 + 0.fb15 i

  {{0, 0x00, 0x0000}, {0, 0x01, 0x0000}}, // w^8  = + cos(8@) + sin(8@)i = + 0.0000 + 1.0000 i

  {{1, 0x00, 0x31f1}, {0, 0x00, 0xfb15}}, // w^9  = - cos(7@) + sin(7@)i ~ - 0.31f1 + 0.fb15 i
  {{1, 0x00, 0x61f8}, {0, 0x00, 0xec83}}, // w^10 = - cos(6@) + sin(6@)i ~ - 0.61f8 + 0.ec83 i
  {{1, 0x00, 0x8e3a}, {0, 0x00, 0xd4db}}, // w^11 = - cos(5@) + sin(5@)i ~ - 0.8e3a + 0.d4db i
  {{1, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^12 = - cos(4@) + sin(4@)i ~ - 0.b505 + 0.b505 i
  {{1, 0x00, 0xd4db}, {0, 0x00, 0x8e3a}}, // w^13 = - cos(3@) + sin(3@)i ~ - 0.d4db + 0.8e3a i
  {{1, 0x00, 0xec83}, {0, 0x00, 0x61f8}}, // w^14 = - cos(2@) + sin(2@)i ~ - 0.ec83 + 0.61f8 i
  {{1, 0x00, 0xfb15}, {0, 0x00, 0x31f1}}, // w^15 = - cos(1@) + sin(1@)i ~ - 0.fb15 + 0.31f1 i

  {{1, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^16 = - cos(0@) + sin(0@)i = - 1.0000 + 0.0000 i

  {{1, 0x00, 0xfb15}, {1, 0x00, 0x31f1}}, // w^17 = - cos(1@) - sin(1@)i ~ - 0.fb15 - 0.31f1 i
  {{1, 0x00, 0xec83}, {1, 0x00, 0x61f8}}, // w^18 = - cos(2@) - sin(2@)i ~ - 0.ec83 - 0.61f8 i
  {{1, 0x00, 0xd4db}, {1, 0x00, 0x8e3a}}, // w^19 = - cos(3@) - sin(3@)i ~ - 0.d4db - 0.8e3a i
  {{1, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^20 = - cos(4@) - sin(4@)i ~ - 0.b505 - 0.b505 i
  {{1, 0x00, 0x8e3a}, {1, 0x00, 0xd4db}}, // w^21 = - cos(5@) - sin(5@)i ~ - 0.8e3a - 0.d4db i
  {{1, 0x00, 0x61f8}, {1, 0x00, 0xec83}}, // w^22 = - cos(6@) - sin(6@)i ~ - 0.61f8 - 0.ec83 i
  {{1, 0x00, 0x31f1}, {1, 0x00, 0xfb15}}, // w^23 = - cos(7@) - sin(7@)i ~ - 0.31f1 - 0.fb15 i

  {{1, 0x00, 0x0000}, {1, 0x01, 0x0000}}, // w^24 = - cos(8@) + sin(8@)i = - 0.0000 - 1.0000 i

  {{0, 0x00, 0x31f1}, {1, 0x00, 0xfb15}}, // w^25 = + cos(7@) - sin(7@)i ~ + 0.31f1 - 0.fb15 i
  {{0, 0x00, 0x61f8}, {1, 0x00, 0xec83}}, // w^26 = + cos(6@) - sin(6@)i ~ + 0.61f8 - 0.ec83 i
  {{0, 0x00, 0x8e3a}, {1, 0x00, 0xd4db}}, // w^27 = + cos(5@) - sin(5@)i ~ + 0.8e3a - 0.d4db i
  {{0, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^28 = + cos(4@) - sin(4@)i ~ + 0.b505 - 0.b505 i
  {{0, 0x00, 0xd4db}, {1, 0x00, 0x8e3a}}, // w^29 = + cos(3@) - sin(3@)i ~ + 0.d4db - 0.8e3a i
  {{0, 0x00, 0xec83}, {1, 0x00, 0x61f8}}, // w^30 = + cos(2@) - sin(2@)i ~ + 0.ec83 - 0.61f8 i
  {{0, 0x00, 0xfb15}, {1, 0x00, 0x31f1}}, // w^31 = + cos(1@) - sin(1@)i ~ + 0.fb15 - 0.31f1 i
};

archvar arctan[24] = {
  {0, 0x00, 0xc910},
  {0, 0x00, 0x76b2},
  {0, 0x00, 0x3eb7},
  {0, 0x00, 0x1fd6},
  {0, 0x00, 0x0ffb},
  {0, 0x00, 0x07ff},
  {0, 0x00, 0x0400},
  {0, 0x00, 0x0200},

  {0, 0x00, 0x0100},
  {0, 0x00, 0x0080},
  {0, 0x00, 0x0040},
  {0, 0x00, 0x0020},
  {0, 0x00, 0x0010},
  {0, 0x00, 0x0008},
  {0, 0x00, 0x0004},
  {0, 0x00, 0x0002},

  {0, 0x00, 0x0001},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
  {0, 0x00, 0x0000},
};

int main() {

  printf("Initiating simulation\n");

  archvar input[27] = {
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},

    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},

    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000}
  };

  archvar kernel[27] = {
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},

    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},

    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000}
  };

  archvar Input[17][3] = {0};
  archvar Kernel[17][3] = {0};
  archvar Product[17][3];
  archvar output[32][2] = {0};

  archvar zero = {0, 0x00, 0x0000};

  print_arch_array("input", 27, input);
  print_arch_array("kernel", 27, kernel);

  dft(input, Input);
  dft(kernel, Kernel);

  print_arch_rec("Input", Input);
  print_arch_rec("Kernel", Kernel);
  // print_arch_rec_10("Input (decimal)", Input);
  // print_arch_rec_10("Kernel (decimal)", Kernel);

  uint32_t hex_pi = (uint32_t)(M_PI*0xffff), hex_half_pi = hex_pi >> 1, hex_three_halves_pi = (3*hex_pi) >> 1, hex_two_pi = hex_pi << 1;
  uint32_t pre_mask = 0x00ff0000, post_mask = 0x0000ffff;

  // Vectorization CORDIC and Flux Multiplier
  for (int N = 0; N < 17; N++) {

    // Store quadrant and remove sign
    bool i_xs = Input[N][0].sign, i_ys = Input[N][1].sign;
    bool k_xs = Kernel[N][0].sign, k_ys = Kernel[N][1].sign;
    int i_q, k_q;

    (!i_xs &  i_ys) ? (i_q = 3) :
    ( i_xs &  i_ys) ? (i_q = 2) :
    ( i_xs & !i_ys) ? (i_q = 1) :
                      (i_q = 0);

    (!k_xs &  k_ys) ? (k_q = 3) :
    ( k_xs &  k_ys) ? (k_q = 2) :
    ( k_xs & !k_ys) ? (k_q = 1) :
                      (k_q = 0);

    Input[N][0].sign = 0; Input[N][1].sign = 0;
    Kernel[N][0].sign = 0; Kernel[N][1].sign = 0;

    uint64_t C = 0, A = 0, B = 0, mask, litA, litB;
    bool At, Bt;

    // printf("\n\tN = %d\ti_q = %d\tk_q = %d\nj\t\tX\t\tY\t\tZ\t\tA\t\tB\t\tC\n", N, i_q, k_q);
    // printf("ini\t\t");
    // print_archvar(Input[N][0]); printf("\t");
    // print_archvar(Input[N][1]); printf("\t");
    // print_archvar(Input[N][2]); printf("\t");
    // printf("%" PRIx64 "\t\t%" PRIx64 "\t\t%" PRIx64 "\n", A, B, C);

    for (int j = 0; j < 24; j++) {            // NOTE: 24 works, upto 32 can be done

      cordic_vec(Input[N], j);
      cordic_vec(Kernel[N], j);

      mask = 1 << (23-j);
      litA = (uint64_t)(Input[N][0].pre << 16) + Input[N][0].post;
      At = litA & mask;

      litB = (uint64_t)(Kernel[N][0].pre << 16) + Kernel[N][0].post;
      Bt = litB & mask;

      C = (C << 2);
      if (Bt) C += A << 1;
      if (At) C += B << 1;
      C += At & Bt;

      A = (A << 1) + At;
      B = (B << 1) + Bt;


      // printf("%x\t\t",j);
      // print_archvar(Input[N][0]); printf("\t");
      // print_archvar(Input[N][1]); printf("\t");
      // print_archvar(Input[N][2]); printf("\t");
      // printf("%" PRIx64 "\t\t%" PRIx64 "\t\t%" PRIx64 "\n", A, B, C);
    }

    // Angle correction
    uint32_t cor_angle = 0;
    if      (i_q == 3) {Input[N][2].sign ^= true; cor_angle = hex_two_pi;}
    else if (i_q == 2) {cor_angle = hex_pi;}
    else if (i_q == 1) {Input[N][2].sign ^= true; cor_angle = hex_pi;}
    archvar cor_angle_arch = {0, (uint8_t)((cor_angle & pre_mask) >> 16), (uint16_t)(cor_angle & post_mask)};
    Input[N][2] = archadd(Input[N][2], cor_angle_arch);

    cor_angle = 0;
    if      (k_q == 3) {Kernel[N][2].sign ^= true; cor_angle = hex_two_pi;}
    else if (k_q == 2) {cor_angle = hex_pi;}
    else if (k_q == 1) {Kernel[N][2].sign ^= true; cor_angle = hex_pi;}
    archvar cor_angle_arch2 = {0, (uint8_t)((cor_angle & pre_mask) >> 16), (uint16_t)(cor_angle & post_mask)};
    Kernel[N][2] = archadd(Kernel[N][2], cor_angle_arch2);

    // Assign Product
    Product[N][0].pre = (uint8_t)(((C >> 16) & pre_mask) >> 16); // maximum expected value: 8*8*pow(1.646760258121064673288,2) = ad.8e73 -> no overflow at N = 32
    Product[N][0].post = (uint16_t)((C >> 16) & post_mask);      
    Product[N][0] = archshiftR(Product[N][0], 5);         // multiply by 1/sqrt(N) twice, for each FFT, so 1/32 aka >>5
    Product[N][0].sign = Input[N][0].sign ^ Kernel[N][0].sign;
    Product[N][2] = archadd(Input[N][2],Kernel[N][2]);

    // printf("Product = ");
    // print_archvar(Product[N][0]);
    // printf("\n");
  }

  print_arch_pol("Input (polar coordinates)", Input);
  print_arch_pol("Kernel (polar coordinates)", Kernel);
  print_arch_pol("Product (polar coordinates)", Product);


  // Rotation CORDIC
  for (int N = 0; N < 17; N++) {

    bool x_sign = 0, y_sign = 0;
    //if (Product[N][2].sign == 1) {y_sign = 1;} // Y reflection
    uint32_t angle = (uint32_t)((Product[N][2].pre << 16) + Product[N][2].post);
    uint32_t mod_angle = angle % (hex_pi << 1), cor_angle = mod_angle;

    if (mod_angle >= hex_three_halves_pi) (x_sign = 0, y_sign = 1, cor_angle = hex_two_pi - mod_angle);
    else if (mod_angle >= hex_pi)         (x_sign = 1, y_sign = 1, cor_angle = mod_angle - hex_pi);
    else if (mod_angle > hex_half_pi)     (x_sign = 1, y_sign = 0, cor_angle = hex_pi - mod_angle);

    Product[N][1] = zero;
    Product[N][2].pre = (uint8_t)((cor_angle & pre_mask) >> 16);
    Product[N][2].post = (uint16_t)(cor_angle & post_mask);
    Product[N][2].sign = 0; // angle is now at Q1

    // printf("\n\tN = %d\nj\t\tX\t\tY\t\tZ\t\t\nini\t\t", N);
    // print_archvar(Product[N][0]); printf("\t");
    // print_archvar(Product[N][1]); printf("\t");
    // print_archvar(Product[N][2]); printf("\n");

    for (int j = 0; j < 17; j++) {    // NOTE: previously at 24, experiment showed max j ~ 0x10 gets better results
      cordic_rot(Product[N], j);

      // printf("%x\t\t",j);
      // print_archvar(Product[N][0]); printf("\t");
      // print_archvar(Product[N][1]); printf("\t");
      // print_archvar(Product[N][2]); printf("\n");
    }

    Product[N][0].sign ^= x_sign;
    Product[N][1].sign ^= y_sign;
}

  print_arch_rec("Product (rectangular coordinates)", Product);

  // Constant Multiplication for CORDIC correction and part of IDFT
  archvar idft_mul[17][2][8] = {0};
  archvar kcon = {0, 0x00, 0x3953}; // kcon = 1 / k^3

  for (int N = 0; N < 17; N++) {
    for (int K = 0; K < 8; K++) { 
      if (
        (  K == 0 )                      || // for V0
        (  N % 2 == 1)                   || // for Vall
        ( (N % 4 == 2) && (K % 2 == 0) ) || // for V2 V4 V6
        ( (N % 8 == 4) && (K == 4))         // for V4
      ) {
        idft_mul[N][0][K] = archmul(Product[N][0], archmul(twiddle_arr[K][0], kcon));
        idft_mul[N][1][K] = archmul(Product[N][1], archmul(twiddle_arr[K][0], kcon)); // this twiddle_arr call is correct
      }
    }
  }

  for (int K = 0; K < 8; K++) {
    print_arch_con(idft_mul, K);
  }

  // Partial IDFT/IFFT
  p_idft(idft_mul, output);

  print_arch_out("output", output);
}