#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include "var.h"
#include "operations.h"


int main(int argc, char *argv[]) {

    archvar input[8] = {
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000}
    };

    archvar kernel[8] = {
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000},
            {0b000000001, 0b0000000000000000}
    };

    archvar Input[9][2];
    archvar Kernel[9][2];

    dft(input, Input);
    dft(kernel, Kernel);

    // ---Hadamard Block---

    archvar product[9][2];

    for (int N = 0; N < 9; N++) {
        bool A, B, An, Bn;
        for (int j = 0; j < 25; j++) {
            An = cordic_vec_dis(Input, j);
            Bn = cordic_vec_dis(Kernel, j);
            if (j != 0) flux_mult(product, A, B, An, Bn, N);
            A = An;
            B = Bn;
        }
        cordic_vec_ang(product, Input, Kernel, N);
    }


}
