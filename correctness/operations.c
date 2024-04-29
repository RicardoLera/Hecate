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
  float temp_var = (float)((var.pre << 16) + var.post);
  temp_var = temp_var / (float)(pow(2,16));
  var.sign ? printf("-%f ", temp_var) : printf("+%f ", temp_var);
}

void print_arch_array(char* name, int j, archvar* arr) {
  printf("\n%s:\n", name);
  for (int i = 0; i < j; i++) (print_archvar(arr[i]), printf("\n"));
}

void print_arch_rec(char* name, archvar arr[17][3]) {
  printf("\n%s:\n", name);
  for (int i = 0; i < 17; i++) (print_archvar(arr[i][0]), print_archvar(arr[i][1]), printf("i\n"));
}

void print_arch_rec_10(char* name, archvar arr[17][3]) {
  printf("\n%s:\n", name);
  for (int i = 0; i < 17; i++) (print_archvar_dec(arr[i][0]), print_archvar_dec(arr[i][1]), printf("i\n"));
}

void print_arch_pol(char* name, archvar arr[17][3]) {
  printf("\n%s:\n", name);
  for (int i = 0; i < 17; i++) (print_archvar(arr[i][0]), printf("angle "), print_archvar(arr[i][2]), printf("\n"));
}

void print_arch_con(archvar arr[17][2][8], int c) {
  printf("\nVariable K%d (N * cos(%d@) * kcon):\n", c, c);
  for (int i = 0; i < 17; i++) (print_archvar(arr[i][0][c]), print_archvar(arr[i][1][c]), printf("i\n"));
}

void print_arch_out (char* name, archvar arr[32][2]) {
  printf("\n%s:\n", name);
  for (int i = 0; i < 32; i++) (print_archvar(arr[i][0]), print_archvar(arr[i][1]), printf("i\n"));
}


//---------------------ARITHMETIC FUNCTIONS


archvar archadd(archvar var1, archvar var2) {
  uint32_t temp_var1 = (uint32_t)((var1.pre << 16) + var1.post);
  uint32_t temp_var2 = (uint32_t)((var2.pre << 16) + var2.post);
  uint32_t temp_res;
  uint8_t temp_sign;

  if (var1.sign ^ var2.sign) { // sign1 XOR sign2 -> if true then signs are different
    if (temp_var1 >= temp_var2) { // -> also ensures that zero has "positive" sign
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

  // if (temp_res == 0x00) temp_sign = 0; // ensure zero has "positive" sign
  if (temp_res > 0x00ffffff) printf("\nWARNING: archadd overflow; full value: %x\n", temp_res);

  uint32_t mask1 = 0x00ff0000;
  uint32_t mask2 = 0x0000ffff;
  archvar res =  {temp_sign, (uint8_t)((temp_res & mask1) >> 16), (uint16_t)(temp_res & mask2)};
  return res;
}

archvar archmul(archvar var1, archvar var2) {
  uint64_t temp_var1 = (uint64_t)((var1.pre << 16) + var1.post);
  uint64_t temp_var2 = (uint64_t)((var2.pre << 16) + var2.post);

  uint64_t temp_res = temp_var1 * temp_var2;
  uint8_t temp_sign = var1.sign ^ var2.sign;

  // if (temp_res == 0x00) temp_sign = 0; // ensure zero has "positive" sign
  if (temp_res > 0x00ffffffffff) printf("\nWARNING: archmul overflow; full value: %lx\n", temp_res);

  uint64_t mask1 = 0x000000ff00000000;
  uint64_t mask2 = 0x00000000ffff0000;
  archvar res = {temp_sign, (uint8_t)((temp_res & mask1) >> 32), (uint16_t)((temp_res & mask2) >> 16)};
  return res;
}

archvar archpow(archvar var, int p) {
  archvar temp_var = var;
  archvar res = {0, 0x01, 0x00};
  for (int i = 0; i < p; i++)
    res =  archmul(res, temp_var);
  return res;
}

archvar archshiftR(archvar var, int s) {
  uint8_t mask = (uint8_t)(pow(2,s)-1), bits;

  bits = var.pre & mask;
  var.pre = var.pre >> s;

  var.post = var.post >> s;
  var.post += (uint16_t)(bits << (16-s));

  return var;
}


//---------------------CONVOLUTION FUNCTIONS

  
void dft(archvar in[27], archvar out[17][3]) {
  archvar temp_in[32], zero = {0, 0x00, 0x0000};

  for (int i = 0; i < 27; i++)
    temp_in[i] = in[i];

  for (int i = 27; i < 32; i++)
    temp_in[i] = zero;

  for (int N = 0; N < 17; N++) {
    for (int i = 0; i < 32; i++) {
      out[N][0] = archadd(out[N][0], archmul(temp_in[i], twiddle_arr[(N*i)%32][0]));
      out[N][1] = archadd(out[N][1], archmul(temp_in[i], twiddle_arr[(N*i)%32][1]));
    }
  }

  // for (int N = 0; N < 17; N++) { // multiply by 1/sqrt(N) so that convolution makes it N and no overflow happens
  //   out[N][0] = archmul(out[N][0], one_over_sqrt32);
  //   out[N][1] = archmul(out[N][1], one_over_sqrt32);
  // }

  // 8*8*pow(1.646760258121064673288,2) = ad.8e73 -> no overflow at N = 32
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

void p_idft(archvar con[17][2][8], archvar out[32][2]) {
  archvar zero = {0, 0x00, 0x0000}, a_wx, a_wy, b_wx, b_wy;
  int C, w_ex, w, wc;

  for (int N = 0; N < 32; N++) {
    for (int i = 0; i < 32; i++) {

      (i <= 16) ? (C = i) : (C = 32-i); // C    -> constant array identifier, corrected for Hermitian Symmetry
      w_ex = (i*N) % 32;                // w_ex -> exponent of w in the full unit circle (0~15)

      ((w_ex > 8 && w_ex <= 16) || (w_ex > 24 && w_ex <= 31)) ? (w = 8 - (w_ex % 8)) : (w = w_ex % 8); // Second and fourth quadrant reflections
      
      (w == 0 || w == 4) ? (wc = w) : (wc = 8 - w); // cos/sin pairs

      //    N     *     w
      // (a + bi) * (wx + wyi) = [ws_x]a*wx + [ws_x]b*wx(i) + [ws_y]a*wy(i) + [-ws_y]b*wy

      bool a_sign  = con[C][0][0].sign;
      bool b_sign  = con[C][1][0].sign;
      bool wx_sign = twiddle_arr[w_ex][0].sign;
      bool wy_sign = twiddle_arr[w_ex][1].sign;

      a_wx = con[C][0][w];
      a_wy = con[C][0][wc];
      b_wx = con[C][1][w];
      b_wy = con[C][1][wc];

      // Signs and cancellations
      if (i > 16) {b_sign ^= true;} // Complex conjugate inversion (b)
      wy_sign ^= true;              // DFT/IDFT inversion

      a_wx.sign = a_sign ^ wx_sign;
      a_wy.sign = a_sign ^ wy_sign;
      b_wx.sign = b_sign ^ wx_sign;
      b_wy.sign = !(b_sign ^ wy_sign); // i^2 inversion

      if (w_ex == 8 || w_ex == 24) {a_wx = zero; b_wx = zero;} // Orthogonal wx cancellation
      if (w_ex == 0 || w_ex == 16) {a_wy = zero; b_wy = zero;} // Orthogonal wy cancellation

      out[N][0] = archadd(out[N][0], archadd(a_wx, b_wy));
      out[N][1] = archadd(out[N][1], archadd(a_wy, b_wx));

      if (N <= 2) {
        if (i==0) {printf("\n");}
        printf("w_ex = %d\tw = %d\twc = %d\tC = %d\tout[%d][0] = ", w_ex, w, wc, C, N);
        print_archvar(out[N][0]);
        printf("\tout[%d][1] = ", N);
        print_archvar(out[N][1]);
        printf("\t R1 = ");
        print_archvar(a_wx);
        printf("\t R2 = ");
        print_archvar(b_wy);
        printf("\t I1 = ");
        print_archvar(a_wy);
        printf("\t I2 = ");
        print_archvar(b_wx);
        printf("\n");
      }
    }
  }
}
