#ifndef OPERATIONS_H
#define OPERATIONS_H

    void dft(archvar in[8], archvar out[9][2]);
    bool cordic_vec_dis(archvar arr[9][2], int j);
    void cordic_vec_ang(archvar prod[9][2], archvar in[9][2], archvar ker[9][2], int N);
    void flux_mult(archvar arr[9][2], bool A, bool B, bool An, bool Bn, int N);

#endif
