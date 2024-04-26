#include <inttypes.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include "var.h"
#include "operations.h"

// We'll make N = 16 because that's the lowest power of two necessary to define 2d convolution

// WARNING: doesn't compile with clang for some reason, only gcc

# define M_PI 3.14159265358979323846

// w^0 ~ w^15
archvar twiddle_arr[16][2] = {
  {{0, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^0 = e^0              = + cos(0pi/8) + 0           = + 1      + 0
  {{0, 0x00, 0xec84}, {0, 0x00, 0x61f8}}, // w^1 = e^(2pi*i/16)     = + cos(pi/8)  + sin(pi/8)i  ~ + 0.ec84 + 0.61f8 i
  {{0, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^2 = e^(2*(2pi*i/16)) = + cos(2pi/8) + sin(2pi/8)i ~ + 0.b505 + 0.b505 i
  {{0, 0x00, 0x61f8}, {0, 0x00, 0xec84}}, // w^3 = e^(3*(2pi*i/16)) = + cos(3pi/8) + sin(3pi/8)i ~ + 0.61f8 + 0.ec84 i
  {{0, 0x00, 0x0000}, {0, 0x01, 0x0000}}, // w^4 = e^(4*(2pi*i/16)) = 0            + sin(4pi/8)  = + 0      + i
  {{1, 0x00, 0x61f8}, {0, 0x00, 0xec84}}, // w^5 = e^(5*(2pi*i/16)) = - cos(5pi/8) + sin(5pi/8)i ~ - 0.61f8 + 0.ec84 i
  {{1, 0x00, 0xb505}, {0, 0x00, 0xb505}}, // w^6 = e^(6*(2pi*i/16)) = - cos(6pi/8) + sin(6pi/8)i ~ - 0.b505 + 0.b505 i
  {{1, 0x00, 0xec84}, {0, 0x00, 0x61f8}}, // w^7 = e^(7*(2pi*i/16)) = - cos(7pi/8) + sin(7pi/8)i ~ - 0.ec84 + 0.61f8 i

  {{1, 0x01, 0x0000}, {0, 0x00, 0x0000}}, // w^8  = -w^0 = - 1      + 0
  {{1, 0x00, 0xec84}, {1, 0x00, 0x61f8}}, // w^9  = -w^1 ~ - 0.ec84 - 0.61f8 i
  {{1, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^10 = -w^2 ~ - 0.b505 - 0.b505 i
  {{1, 0x00, 0x61f8}, {1, 0x00, 0xec84}}, // w^11 = -w^3 ~ - 0.61f8 - 0.ec84 i
  {{0, 0x00, 0x0000}, {1, 0x01, 0x0000}}, // w^12 = -w^4 = + 0      - i
  {{0, 0x00, 0x61f8}, {1, 0x00, 0xec84}}, // w^13 = -w^5 ~ + 0.61f8 - 0.ec84 i
  {{0, 0x00, 0xb505}, {1, 0x00, 0xb505}}, // w^14 = -w^6 ~ + 0.b505 - 0.b505 i
  {{0, 0x00, 0xec84}, {1, 0x00, 0x61f8}}  // w^15 = -w^7 ~ + 0.ec84 - 0.61f8 i
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

  archvar input[8] = {
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000}
  };

  archvar kernel[8] = {
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x01, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000},
    {0, 0x00, 0x0000}
  };

  archvar Input[9][3] = {0};    // x / y / alpha
  archvar Kernel[9][3] = {0};
  archvar Product[9][3];
  archvar output[16][2] = {0};

  archvar zero = {0, 0x00, 0x0000};

  print_arch_array("input", 8, input);
  print_arch_array("kernel", 8, kernel);

  dft(input, Input);
  dft(kernel, Kernel);

  print_arch_rec("Input", Input);
  print_arch_rec("Kernel", Kernel);
  print_arch_rec_10("Input (decimal)", Input);
  print_arch_rec_10("Kernel (decimal)", Kernel);

  uint32_t hex_pi = (uint32_t)(M_PI*0xffff), hex_half_pi = hex_pi >> 1, hex_three_halves_pi = (3*hex_pi) >> 1, hex_two_pi = hex_pi << 1;
  uint32_t pre_mask = 0x00ff0000, post_mask = 0x0000ffff;

  // Vectorization CORDIC and Flux Multiplier
  for (int N = 0; N < 9; N++) {

    // Store quadrant and remove sign
    bool i_xs = Input[N][0].sign, i_ys = Input[N][1].sign;
    bool k_xs = Kernel[N][0].sign, k_ys = Kernel[N][1].sign;
    int i_q, k_q;

    ( i_xs & !i_ys) ? (i_q = 3) :
    (!i_xs & !i_ys) ? (i_q = 2) :
    (!i_xs &  i_ys) ? (i_q = 1) :
                      (i_q = 0);

    ( k_xs & !k_ys) ? (k_q = 3) :
    (!k_xs & !k_ys) ? (k_q = 2) :
    (!k_xs &  k_ys) ? (k_q = 1) :
                      (k_q = 0);

    Input[N][0].sign = 0; Input[N][1].sign = 0;
    Kernel[N][0].sign = 0; Kernel[N][1].sign = 0;

    uint64_t C = 0, A = 0, B = 0, mask, litA, litB;
    bool At, Bt;

    printf("\n\tN = %d\nj\t\tX\t\tY\t\tZ\t\tA\t\tB\t\tC\n", N);
    printf("ini\t\t");
    print_archvar(Input[N][0]); printf("\t");
    print_archvar(Input[N][1]); printf("\t");
    print_archvar(Input[N][2]); printf("\t");
    printf("%" PRIx64 "\t\t%" PRIx64 "\t\t%" PRIx64 "\n", A, B, C);

    for (int j = 0; j < 24; j++) {

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


      printf("%x\t\t",j);
      print_archvar(Input[N][0]); printf("\t");
      print_archvar(Input[N][1]); printf("\t");
      print_archvar(Input[N][2]); printf("\t");
      printf("%" PRIx64 "\t\t%" PRIx64 "\t\t%" PRIx64 "\n", A, B, C);
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
    Product[N][0].pre = (uint8_t)(((C >> 16) & pre_mask) >> 16);
    Product[N][0].post = (uint16_t)((C >> 16) & post_mask);
    Product[N][0].sign = Input[N][0].sign ^ Kernel[N][0].sign;
    Product[N][2] = archadd(Input[N][2],Kernel[N][2]);


    printf("Product = ");
    print_archvar(Product[N][0]);
    printf("\n");
  }


  print_arch_pol("Input (polar coordinates)", Input);
  print_arch_pol("Kernel (polar coordinates)", Kernel);
  print_arch_pol("Product (polar coordinates)", Product);


  // Rotation CORDIC
  for (int N = 0; N < 9; N++) {

    bool x_sign = 0, y_sign = 0;
    if (Product[N][2].sign == 1) {y_sign = 1;} // Y reflection
    uint32_t angle = (uint32_t)((Product[N][2].pre << 16) + Product[N][2].post);
    uint32_t mod_angle = angle % (hex_pi << 1), cor_angle = mod_angle;

    if (mod_angle >= hex_three_halves_pi) (x_sign = 0, y_sign ^= true, cor_angle = hex_two_pi - mod_angle);
    else if (mod_angle >= hex_pi)         (x_sign = 1, y_sign ^= true, cor_angle = mod_angle - hex_pi);
    else if (mod_angle > hex_half_pi)     (x_sign = 1, cor_angle = hex_pi - mod_angle);

    Product[N][1] = zero;
    Product[N][2].pre = (uint8_t)((cor_angle & pre_mask) >> 16);
    Product[N][2].post = (uint16_t)(cor_angle & post_mask);
    Product[N][2].sign = 0; // angle is now at Q1

    printf("\n\tN = %d\nj\t\tX\t\tY\t\tZ\t\t\nini\t\t", N);
    print_archvar(Product[N][0]); printf("\t");
    print_archvar(Product[N][1]); printf("\t");
    print_archvar(Product[N][2]); printf("\n");

    for (int j = 0; j < 13; j++) {    // Max j = 12
      cordic_rot(Product[N], j);

      printf("%x\t\t",j);
      print_archvar(Product[N][0]); printf("\t");
      print_archvar(Product[N][1]); printf("\t");
      print_archvar(Product[N][2]); printf("\n");
    }

    Product[N][0].sign ^= x_sign;
    Product[N][1].sign ^= y_sign;
}

  print_arch_rec("Product (rectangular coordinates)", Product);

  // Constant Multiplication for CORDIC correction and part of IDFT
  archvar idft_mul[9][2][4] = {0};
  archvar kcon = {0, 0x00, 0x3953}; // kcon = 1 / k^3
  archvar V = archmul(twiddle_arr[0][0], kcon); // cos(0)     * kcon
  archvar W = archmul(twiddle_arr[1][0], kcon); // cos(pi/8)  * kcon
  archvar X = archmul(twiddle_arr[2][0], kcon); // cos(2pi/8) * kcon
  archvar Y = archmul(twiddle_arr[3][0], kcon); // cos(3pi/8) * kcon

  for (int N = 0; N < 9; N++) {
    // if (N == 0 || N%2 == 1) {
      idft_mul[N][0][0] = archmul(Product[N][0], V);
      idft_mul[N][1][0] = archmul(Product[N][1], V);
    // }
    // if (N%2 == 1) {
      idft_mul[N][0][1] = archmul(Product[N][0], W);
      idft_mul[N][1][1] = archmul(Product[N][1], W);

      idft_mul[N][0][2] = archmul(Product[N][0], X);
      idft_mul[N][1][2] = archmul(Product[N][1], X);

      idft_mul[N][0][3] = archmul(Product[N][0], Y);
      idft_mul[N][1][3] = archmul(Product[N][1], Y);
    // }
    // if (N == 2 || N == 6) {
    //   idft_mul[N][0][2] = archmul(Product[N][0], X);
    //   idft_mul[N][1][2] = archmul(Product[N][1], X);
    // }
  }

  print_arch_con("Variable V (N * cos(0) * kcon)", idft_mul, 0);
  print_arch_con("Variable W (N * cos(pi/8) * kcon)", idft_mul, 1);
  print_arch_con("Variable X (N * cos(2pi/8) * kcon)", idft_mul, 2);
  print_arch_con("Variable Y (N * cos(3pi/8) * kcon)", idft_mul, 3);

  // Partial IDFT/IFFT
  p_idft(idft_mul, output);

  print_arch_out("output", output);
}










  // printf("\n\nTesting Archvar Addition:\n\n");
  // archvar var1 = {1, 0x02, 0x1000};
  // print_archvar(var1);
  // archvar var2 = {0, 0x05, 0x0003};
  // print_archvar(var2);
  // archvar res = archadd(var1, var2);
  // print_archvar(res);

  // printf("\n\nTesting Archvar Multiplication:\n\n");
  // archvar var3 = {1, 0x02,0x0000};
  // print_archvar(var3);
  // archvar var4 = {1, 0x05, 0x0003};
  // print_archvar(var4);
  // archvar res2 = archmul(var3, var4);
  // print_archvar(res2);

  // printf("\n\nTesting Archvar Exponentiation:\n\n");
  // archvar var = {0, 0x05, 0x0003};
  // res = archpow(var, 2);
  // print_archvar(res);

  // printf("\n\nTesting Archvar Right Shift:\n\n");
  // archvar sh = {0, 0x01, 0x41c0};
  // sh = archshiftR(sh, 1);
  // print_archvar(sh);
  // printf("\n\n");



  //  int j = 25;

  //  printf("\n\nThe Table for j = %d:\n\n", j);
  //  archvar arr[2], tarr;

  //  arr[0].sign = 0;
  //  arr[0].pre  = 0x00;
  //  arr[0].post = 0x4000;

  //  arr[1].sign = 0;
  //  arr[1].pre  = 0x01;
  //  arr[1].post = 0x41c0;

  //  for (int i; i < j; i++) {
  //      if (arr[1].sign == 1) {
  //          tarr = arr[0];

  //          arr[1].sign = ~arr[1].sign;
  //          arr[0] = archadd(arr[0], archshiftR(arr[1], i));
  //          arr[1].sign = ~arr[1].sign;

  //          arr[1] = archadd(arr[1], archshiftR(tarr, i));
  //      }
  //      else {
  //          tarr = arr[1];

  //          arr[0].sign = ~arr[0].sign;
  //          arr[1] = archadd(arr[1], archshiftR(arr[0], i));
  //          arr[0].sign = ~arr[0].sign;

  //          arr[0] = archadd(arr[0], archshiftR(tarr, i));
  //      }

  //      printf("\nTable line %d: ", i);
  //      print_archvar(arr[0]);
  //      printf("+ ");
  //      print_archvar(arr[1]);
  //      printf("i\n");
  //  }
