#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <math.h>
#include "var.h"
#include "operations.h"

# define M_PI 3.14159265358979323846

// w^0 ~ w^15
archvar twiddle_arr[16][2] = {
        {{0b0, 0x01, 0x0000}, {0b0, 0x00, 0x0000}}, // w^0 = e^0              = + cos(0pi/8) + 0           = + 1      + 0
        {{0b0, 0x00, 0xec84}, {0b0, 0x00, 0x61f8}}, // w^1 = e^(2pi*i/16)     = + cos(pi/8)  + sin(pi/8)i  ~ + 0.ec84 + 0.61f8 i
        {{0b0, 0x00, 0xb505}, {0b0, 0x00, 0xb505}}, // w^2 = e^(2*(2pi*i/16)) = + cos(2pi/8) + sin(2pi/8)i ~ + 0.b505 + 0.b505 i
        {{0b0, 0x00, 0x61f8}, {0b0, 0x00, 0xec84}}, // w^3 = e^(3*(2pi*i/16)) = + cos(3pi/8) + sin(3pi/8)i ~ + 0.61f8 + 0.ec84 i
        {{0b0, 0x00, 0x0000}, {0b0, 0x01, 0x0000}}, // w^4 = e^(4*(2pi*i/16)) = 0            + sin(4pi/8)  = + 0      + i
        {{0b1, 0x00, 0x61f8}, {0b0, 0x00, 0xec84}}, // w^5 = e^(5*(2pi*i/16)) = - cos(5pi/8) + sin(5pi/8)i ~ - 0.61f8 + 0.ec84 i
        {{0b1, 0x00, 0xb505}, {0b0, 0x00, 0xb505}}, // w^6 = e^(6*(2pi*i/16)) = - cos(6pi/8) + sin(6pi/8)i ~ - 0.b505 + 0.b505 i
        {{0b1, 0x00, 0xec84}, {0b0, 0x00, 0x61f8}}, // w^7 = e^(7*(2pi*i/16)) = - cos(7pi/8) + sin(7pi/8)i ~ - 0.ec84 + 0.61f8 i

        {{0b1, 0x01, 0x0000}, {0b0, 0x00, 0x0000}}, // w^8  = -w^0 = - 1      + 0
        {{0b1, 0x00, 0xec84}, {0b1, 0x00, 0x61f8}}, // w^9  = -w^1 ~ - 0.ec84 - 0.61f8 i
        {{0b1, 0x00, 0xb505}, {0b1, 0x00, 0xb505}}, // w^10 = -w^2 ~ - 0.b505 - 0.b505 i
        {{0b1, 0x00, 0x61f8}, {0b1, 0x00, 0xec84}}, // w^11 = -w^3 ~ - 0.61f8 - 0.ec84 i
        {{0b0, 0x00, 0x0000}, {0b1, 0x01, 0x0000}}, // w^12 = -w^4 = + 0      - i
        {{0b0, 0x00, 0x61f8}, {0b1, 0x00, 0xec84}}, // w^13 = -w^5 ~ + 0.61f8 - 0.ec84 i
        {{0b0, 0x00, 0xb505}, {0b1, 0x00, 0xb505}}, // w^14 = -w^6 ~ + 0.b505 - 0.b505 i
        {{0b0, 0x00, 0xec84}, {0b1, 0x00, 0x61f8}}  // w^15 = -w^7 ~ + 0.ec84 - 0.61f8 i
};

archvar arctan[24] = {
        {0b0, 0x00, 0xc910},
        {0b0, 0x00, 0x76b2},
        {0b0, 0x00, 0x3eb7},
        {0b0, 0x00, 0x1fd6},
        {0b0, 0x00, 0x0ffb},
        {0b0, 0x00, 0x07ff},
        {0b0, 0x00, 0x0400},
        {0b0, 0x00, 0x0200},

        {0b0, 0x00, 0x0100},
        {0b0, 0x00, 0x0080},
        {0b0, 0x00, 0x0040},
        {0b0, 0x00, 0x0020},
        {0b0, 0x00, 0x0010},
        {0b0, 0x00, 0x0008},
        {0b0, 0x00, 0x0004},
        {0b0, 0x00, 0x0002},

        {0b0, 0x00, 0x0001},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
        {0b0, 0x00, 0x0000},
};



int main(int argc, char *argv[]) {

    printf("Initiating simulation\n");

    archvar input[8] = {
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000}
    };

    archvar kernel[8] = {
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000},
            {0b0, 0x01, 0x0000}
    };

    archvar Input[9][3] = {0};    // x / y / alpha
    archvar Kernel[9][3] = {0};
    archvar Product[9][3];
    archvar output[16][2] = {0};

    archvar zero = {0b0, 0x00, 0x0000};

    print_arch_array("input", 8, input);
    print_arch_array("kernel", 8, kernel);

    dft(input, Input);
    dft(kernel, Kernel);

    print_arch_rec("Input", Input);
    print_arch_rec("Kernel", Kernel);
    print_arch_rec_10("Input (decimal)", Input);
    print_arch_rec_10("Kernel (decimal)", Kernel);

    // Vectorization CORDIC and Flux Multiplier
    for (int N = 0; N < 9; N++) {
        uint64_t C = 0, A = 0, B = 0, mask, litA, litB;
        bool At, Bt;
        for (int j = 0; j < 24; j++) {

            cordic_vec(Input[N], j);
            cordic_vec(Kernel[N], j);

            mask = pow(2, 23-j);
            litA = (Input[N][0].pre << 16) + Input[N][0].post;
            At = litA & mask;

            litB = (Kernel[N][0].pre << 16) + Kernel[N][0].post;
            Bt = litB & mask;

            C = (C << 2);
            if (Bt) C += A << 1;
            if (At) C += B << 1;
            C += At & Bt;

            A = (A << 1) + At;
            B = (B << 1) + Bt;
        }
        uint32_t pre_mask = 0x00ff0000, post_mask = 0x0000ffff;
        Product[N][0].pre = ((C >> 16) & pre_mask) >> 16;
        Product[N][0].post = (C >> 16) & post_mask;
        Product[N][0].sign = Input[N][0].sign ^ Kernel[N][0].sign;
        Product[N][2] = archadd(Input[N][2],Kernel[N][2]);
    }

    print_arch_pol("Input (polar coordinates)", Input);
    print_arch_pol("Kernel (polar coordinates)", Kernel);
    print_arch_pol("Product (polar coordinates)", Product);

    // Rotation CORDIC
    for (int N = 0; N < 9; N++) {

        bool x_sign = 0, y_sign = 0;
        uint32_t angle = (Product[N][2].pre << 16) + Product[N][2].post;
        uint32_t hex_pi = M_PI*0xffff, hex_half_pi = hex_pi >> 1, hex_three_halves_pi = (3*hex_pi) >> 1;
        uint32_t mod_angle = angle % (hex_pi << 1), cor_angle = mod_angle;
        uint32_t pre_mask = 0x00ff0000, post_mask = 0x0000ffff;

        if (mod_angle >= hex_three_halves_pi) (x_sign = 0, y_sign = 1, cor_angle = (hex_pi << 1) - mod_angle);
        else if (mod_angle >= hex_pi)         (x_sign = 1, y_sign = 1, cor_angle = mod_angle - hex_pi);
        else if (mod_angle > hex_half_pi)     (x_sign = 1, y_sign = 0, cor_angle = hex_pi - mod_angle);

        Product[N][1] = zero;
        Product[N][2].pre = (cor_angle & pre_mask) >> 16;
        Product[N][2].post = cor_angle & post_mask;

        for (int j = 0; j < 24; j++)
            cordic_rot(Product[N], j);

        Product[N][0].sign = x_sign;
        Product[N][1].sign = y_sign;
    }

    print_arch_rec("Product (rectangular coordinates)", Product);

    // Constant Multiplication for CORDIC correction and part of IDFT
    archvar idft_mul[9][2][4] = {0};
    archvar kcon = {0b0, 0x00, 0x3953}; // kcon = 1 / k^3
    archvar V = archmul(twiddle_arr[0][0], kcon); // cos(0)     * kcon
    archvar W = archmul(twiddle_arr[1][0], kcon); // cos(pi/8)  * kcon
    archvar X = archmul(twiddle_arr[2][0], kcon); // cos(2pi/8) * kcon
    archvar Y = archmul(twiddle_arr[3][0], kcon); // cos(3pi/8) * kcon

    for (int N = 0; N < 9; N++) {
        idft_mul[N][0][0] = archmul(Product[N][0], V);
        idft_mul[N][1][0] = archmul(Product[N][1], V);

        if (N%2 == 1) {
            idft_mul[N][0][1] = archmul(Product[N][0], W);
            idft_mul[N][1][1] = archmul(Product[N][1], W);

            idft_mul[N][0][2] = archmul(Product[N][0], X);
            idft_mul[N][1][2] = archmul(Product[N][1], X);

            idft_mul[N][0][3] = archmul(Product[N][0], Y);
            idft_mul[N][1][3] = archmul(Product[N][1], Y);
        }
        else if (N == 2 || N == 6) {
            idft_mul[N][0][2] = archmul(Product[N][0], X);
            idft_mul[N][1][2] = archmul(Product[N][1], X);
        }
    }

    print_arch_con("Variable V (N * cos(0) * kcon)", idft_mul, 0);
    print_arch_con("Variable W (N * cos(pi/8) * kcon)", idft_mul, 1);
    print_arch_con("Variable X (N * cos(2pi/8) * kcon)", idft_mul, 2);
    print_arch_con("Variable Y (N * cos(3pi/8) * kcon)", idft_mul, 3);

    // Partial IDFT/IFFT
    p_idft(idft_mul, output);

    print_arch_out("output", output);















    printf("\n\nTesting Archvar Addition:\n\n");
    archvar var1 = {0b1, 0x02, 0x1000};
    print_archvar(var1);
    archvar var2 = {0b0, 0x05, 0x0003};
    print_archvar(var2);
    archvar res = archadd(var1, var2);
    print_archvar(res);

    printf("\n\nTesting Archvar Multiplication:\n\n");
    archvar var3 = {0b1, 0x02,0x0000};
    print_archvar(var3);
    archvar var4 = {0b1, 0x05, 0x0003};
    print_archvar(var4);
    archvar res2 = archmul(var3, var4);
    print_archvar(res2);

    printf("\n\nTesting Archvar Exponentiation:\n\n");
    archvar var = {0b0, 0x05, 0x0003};
    res = archpow(var, 2);
    print_archvar(res);

    printf("\n\nTesting Archvar Right Shift:\n\n");
    archvar sh = {0b0, 0x01, 0x41c0};
    sh = archshiftR(sh, 1);
    print_archvar(sh);
    printf("\n\n");



//    int j = 25;
//
//    printf("\n\nThe Table for j = %d:\n\n", j);
//    archvar arr[2], tarr;
//
//    arr[0].sign = 0b0;
//    arr[0].pre  = 0x00;
//    arr[0].post = 0x4000;
//
//    arr[1].sign = 0b0;
//    arr[1].pre  = 0x01;
//    arr[1].post = 0x41c0;
//
//    for (int i; i < j; i++) {
//        if (arr[1].sign == 1) {
//            tarr = arr[0];
//
//            arr[1].sign = ~arr[1].sign;
//            arr[0] = archadd(arr[0], archshiftR(arr[1], i));
//            arr[1].sign = ~arr[1].sign;
//
//            arr[1] = archadd(arr[1], archshiftR(tarr, i));
//        }
//        else {
//            tarr = arr[1];
//
//            arr[0].sign = ~arr[0].sign;
//            arr[1] = archadd(arr[1], archshiftR(arr[0], i));
//            arr[0].sign = ~arr[0].sign;
//
//            arr[0] = archadd(arr[0], archshiftR(tarr, i));
//        }
//
//        printf("\nTable line %d: ", i);
//        print_archvar(arr[0]);
//        printf("+ ");
//        print_archvar(arr[1]);
//        printf("i\n");
//    }

}
