#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include "var.h"

# define M_PI 3.14159265358979323846


//---------------------PRINT FUNCTIONS


void print_archvar(archvar var) {
    var.sign ? printf("-%02x.%04x ", var.pre, var.post) : printf("+%02x.%04x ", var.pre, var.post);
}

void print_archvar_dec(archvar var) {
    float temp_var = (var.pre << 16) + var.post;
    temp_var = temp_var / pow(2,16);
    var.sign ? printf("-%f ", temp_var) : printf("+%f ", temp_var);
}

void print_arch_array(char* name, int j, archvar* arr) {
    printf("\n%s:\n", name);
    for (int i = 0; i < j; i++) (print_archvar(arr[i]), printf("\n"));
}

void print_arch_rec(char* name, archvar arr[9][3]) {
    printf("\n%s:\n", name);
    for (int i = 0; i < 9; i++) (print_archvar(arr[i][0]), print_archvar(arr[i][1]), printf("i\n"));
}

void print_arch_rec_10(char* name, archvar arr[9][3]) {
    printf("\n%s:\n", name);
    for (int i = 0; i < 9; i++) (print_archvar_dec(arr[i][0]), print_archvar_dec(arr[i][1]), printf("i\n"));
}

void print_arch_pol(char* name, archvar arr[9][3]) {
    printf("\n%s:\n", name);
    for (int i = 0; i < 9; i++) (print_archvar(arr[i][0]), printf("angle "), print_archvar(arr[i][2]), printf("\n"));
}

void print_arch_con(char* name, archvar arr[9][2][4], int c) {
    printf("\n%s:\n", name);
    for (int i = 0; i < 9; i++) (print_archvar(arr[i][0][c]), print_archvar(arr[i][1][c]), printf("i\n"));
}

void print_arch_out (char* name, archvar arr[16][2]) {
    printf("\n%s:\n", name);
    for (int i = 0; i < 16; i++) (print_archvar(arr[i][0]), print_archvar(arr[i][1]), printf("i\n"));
}


//---------------------ARITHMETIC FUNCTIONS


archvar archadd(archvar var1, archvar var2) {
    uint32_t temp_var1 = (var1.pre << 16) + var1.post;
    uint32_t temp_var2 = (var2.pre << 16) + var2.post;
    uint32_t temp_res;
    uint8_t temp_sign;

    if (var1.sign ^ var2.sign) { // sign1 XOR sign2 -> if true then signs are different
        if (temp_var1 >= temp_var2) {           // >= also ensures that zero has "positive" sign
            temp_res = temp_var1 - temp_var2;
            temp_sign = var1.sign;
        }
        else {
            temp_res = temp_var2 - temp_var1;
            temp_sign = var2.sign;
        }
    }
    else {
        temp_res = temp_var1 + temp_var2;
        temp_sign = var1.sign;
    }

    if (temp_res == 0x00) temp_sign = 0b0; // ensure zero has "positive" sign
    if (temp_res > 0x00ffffff) printf("\nWARNING: archadd overflow; full value: %x\n", temp_res);

    uint32_t mask1 = 0x00ff0000;
    uint32_t mask2 = 0x0000ffff;
    archvar res =  {temp_sign, (temp_res & mask1) >> 16, temp_res & mask2};
    return res;
}

archvar archmul(archvar var1, archvar var2) {
    uint64_t temp_var1 = (var1.pre << 16) + var1.post;
    uint64_t temp_var2 = (var2.pre << 16) + var2.post;

    uint64_t temp_res = temp_var1 * temp_var2;
    uint8_t temp_sign = var1.sign ^ var2.sign;

    if (temp_res == 0x00) temp_sign = 0b0; // ensure zero has "positive" sign
    if (temp_res > 0x00ffffffffff) printf("\nWARNING: archmul overflow; full value: %lx\n", temp_res);

    uint64_t mask1 = 0x000000ff00000000;
    uint64_t mask2 = 0x00000000ffff0000;
    archvar res =  {temp_sign, (temp_res & mask1) >> 32, (temp_res & mask2) >> 16};
    return res;
}

archvar archpow(archvar var, int p) {
    archvar temp_var = var;
    archvar res = {0b0, 0x01, 0x00};
    for (int i = 0; i < p; i++)
        res =  archmul(res, temp_var);
    return res;
}

archvar archshiftR(archvar var, int s) {
    uint8_t mask = pow(2,s)-1, bits;

    bits = var.pre & mask;
    var.pre = var.pre >> s;

    var.post = var.post >> s;
    var.post += bits << (16-s);

    return var;
}


//---------------------CONVOLUTION FUNCTIONS


void dft(archvar in[8], archvar out[9][3]) {
    archvar temp_in[16], zero = {0b0, 0x00, 0x0000}, one_over_four = {0b0, 0x00, 0x4000};

    for (int i = 0; i < 8; i++)
        temp_in[i] = in[i];

    for (int i = 8; i < 16; i++)
        temp_in[i] = zero;

    for (int N = 0; N < 9; N++) {
        for (int i = 0; i < 16; i++) {
            out[N][0] = archadd(out[N][0], archmul(temp_in[i], twiddle_arr[(N*i)%16][0]));
            out[N][1] = archadd(out[N][1], archmul(temp_in[i], twiddle_arr[(N*i)%16][1]));
        }
    }

    for (int N = 0; N < 9; N++) { // multiply by 1/sqrtN aka 1/4
        out[N][0] = archmul(out[N][0], one_over_four);
        out[N][1] = archmul(out[N][1], one_over_four);
    }
}

void cordic_vec(archvar arr[3], int j) {

    archvar tarr, tcon;

    if (arr[1].sign == 1) {
        tarr = arr[0];

        arr[1].sign = !arr[1].sign;
        arr[0] = archadd(arr[0], archshiftR(arr[1], j));
        arr[1].sign = !arr[1].sign;

        arr[1] = archadd(arr[1], archshiftR(tarr, j));

        tcon = arctan[j];
        tcon.sign = !tcon.sign;
        arr[2] = archadd(arr[2], tcon);
    }
    else {
        tarr = arr[1];

        arr[0].sign = !arr[0].sign;
        arr[1] = archadd(arr[1], archshiftR(arr[0], j));
        arr[0].sign = !arr[0].sign;

        arr[0] = archadd(arr[0], archshiftR(tarr, j));

        tcon = arctan[j];
        arr[2] = archadd(arr[2], tcon);
    }
}

void cordic_rot(archvar arr[3], int j) {

    archvar tarr, tcon;

    if (arr[2].sign == 0) {
        tarr = arr[0];

        arr[1].sign = !arr[1].sign;
        arr[0] = archadd(arr[0], archshiftR(arr[1], j));
        arr[1].sign = !arr[1].sign;

        arr[1] = archadd(arr[1], archshiftR(tarr, j));

        tcon = arctan[j];
        tcon.sign = !tcon.sign;
        arr[2] = archadd(arr[2], tcon);
    }
    else {
        tarr = arr[1];

        arr[0].sign = !arr[0].sign;
        arr[1] = archadd(arr[1], archshiftR(arr[0], j));
        arr[0].sign = !arr[0].sign;

        arr[0] = archadd(arr[0], archshiftR(tarr, j));

        tcon = arctan[j];
        arr[2] = archadd(arr[2], tcon);
    }
}

void p_idft(archvar con[9][2][4], archvar out[16][2]) {
    archvar zero = {0b0, 0x00, 0x0000}, tconR[2], tconI[2];
    int C, mod_i, mod_ic, w, wc;

    for (int N = 0; N < 16; N++) {
        for (int i = 0; i < 16; i++) {

            (i < 9) ? (C = i) : (C = i-8); // C     -> constant array identifier, corrected for Complex conjugate
            mod_i = (i*N) % 16;            // mod_i -> exponent of w in the full unit circle (0~15)
            mod_ic = (16-mod_i) % 16;
            w = mod_i % 4;                 // w     -> exponent of w in quadrant 1 (0~3)
            wc = (4-w) % 4;                // wc    -> equivalent exponent of imaginary part of w (e.g. w_(16)^(1) = cos(w1) + cos(w3)i)

            //    N     *     w
            // (a + bi) * (wx + wyi) = [ws_x]a*wx + [ws_x]b*wx(i) + [ws_y]a*wy(i) + [-ws_y]b*wy

            // The following values so far account for [N * kcon * cos(w)]
            tconR[0] = con[C][0][w];  // a*wx
            tconR[1] = con[C][1][wc]; // b*wy
            tconI[0] = con[C][0][wc]; // a*wy
            tconI[1] = con[C][1][w];  // b*wx

            // Signs and cancellations:
            tconR[1].sign ^= true;                                                           // b*wy*i^2 inversion
            if (twiddle_arr[mod_ic][0].sign) (tconR[0].sign ^= true, tconI[1].sign ^= true); // wx quadrant sign
            if (twiddle_arr[mod_ic][1].sign) (tconI[0].sign ^= true, tconR[1].sign ^= true); // wy quadrant sign
            if (i >= 9) (tconR[1].sign ^= true, tconI[1].sign ^= true);                      // Complex conjugate inversion (b)
            if (mod_ic == 4 || mod_ic == 12) (tconR[0] = zero, tconI[1] = zero);             // Orthogonal X cancellation
            if (mod_ic == 0 || mod_ic == 8)  (tconR[1] = zero, tconI[0] = zero);             // Orthogonal Y cancellation

            out[N][0] = archadd(out[N][0], archadd(tconR[0], tconR[1]));
            out[N][1] = archadd(out[N][1], archadd(tconI[0], tconI[1]));


            //if (N==0 && i==0) printf("\n");
            //printf("%2d ", tconR[0].sign);
            //print_archvar(tconR[1]);
            //if (i == 15) printf("\n");









            //uint32_t hex_pi = M_PI*0xffff, hex_half_pi = hex_pi >> 1, hex_three_halves_pi = (3*hex_pi) >> 1;

            //uint32_t angle = (prod[N][2].pre << 16) + prod[N][2].post;
            //uint32_t Q = ((mod_i*0x6488 + angle) % (hex_pi << 1)); // Find final angle within 2pi

            //if (Q >= hex_three_halves_pi) (temp_conR.sign = 0, temp_conI.sign = 1); // Q1 ->  R ~I
            //else if (Q >= hex_pi)         (temp_conR.sign = 1, temp_conI.sign = 1); // Q2 -> ~R ~I
            //else if (Q > hex_half_pi)     (temp_conR.sign = 1, temp_conI.sign = 0); // Q3 -> ~R  I
            //else                          (temp_conR.sign = 0, temp_conI.sign = 0); // Q4 ->  R  I

            //if (twiddle_arr[mod_i][0].sign) temp_conR.sign = ~temp_conR.sign;
            //if (twiddle_arr[mod_i][1].sign) temp_conI.sign = ~temp_conI.sign;
            //if (mod_i==4 || mod_i==12) temp_conR = zero;                 // Orthogonal X cancellation
            //if (mod_i==0 || mod_i==8)  temp_conI = zero;                 // Orthogonal Y cancellation

            //bool xs = temp_conR.sign, ys = temp_conI.sign; int Q;
            //(!xs && !ys) ? (Q = 1) : ( (xs && !ys) ? (Q = 2) : (xs && ys) ? (Q = 3) : (Q = 4)); // Find quadrant
            //Q = (Q + (mod_i >> 2) )%4 + 1; // Rotate by w

            //if (Q == 1)      (xs = 0, ys = 0);
            //else if (Q == 2) (xs = 1, ys = 0);
            //else if (Q == 3) (xs = 1, ys = 1);
            //else if (Q == 4) (xs = 0, ys = 1);

            //if (mod_i>4 && mod_i<12)   temp_conR.sign = ~temp_conR.sign; // Quadrants 2 & 3 -> Real part negative
            //if (mod_i>8)               temp_conI.sign = ~temp_conI.sign; // Quadrants 3 & 4 -> Imaginary part negative

            // If clockwise rotation is assumed, the third clause becomes (mod_i<8) and the answer becomes its conjugate
        }
    }







    //for (int N = 0; N < 15; N++) {
    //    out[N][0] = archmul(out[N][0], one_over_four);
    //    out[N][1] = archmul(out[N][1], one_over_four);
    //}
}






//for (int i = 4; i < 8; i++) { // Quadrant 2: ~R I
//    con[C][0][i].sign = ~con[C][0][i].sign;
//    out[N][0] = archadd(out[N][0], con[C][0][i]);
//    out[N][1] = archadd(out[N][1], con[C][1][i]);
//    con[C][0][i].sign = ~con[C][0][i].sign;
//}
//for (int i = 8; i < 12; i++) { // Quadrant 3: ~R ~I
//    con[C][0][i].sign = ~con[C][0][i].sign;
//    con[C][0][i].sign = ~con[C][1][i].sign;
//    out[N][0] = archadd(out[N][0], con[C][0][i]);
//    out[N][1] = archadd(out[N][1], con[C][1][i]);
//    con[C][0][i].sign = ~con[C][0][i].sign;
//    con[C][0][i].sign = ~con[C][1][i].sign;
//}
//for (int i = 12; i < 16; i++) { // Quadrant 4: R ~I
//    con[C][0][i].sign = ~con[C][1][i].sign;
//    out[N][0] = archadd(out[N][0], con[C][0][i]);
//    out[N][1] = archadd(out[N][1], con[C][1][i]);
//    con[C][0][i].sign = ~con[C][1][i].sign;
//}
