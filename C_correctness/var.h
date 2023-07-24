#ifndef VAR_H
#define VAR_H

    typedef struct archvar {
        unsigned int aux: 9;
        signed int core: 16;
    } archvar;

    extern archvar twiddle_arr[8];
    extern archvar twiddle_mat[8][8];

#endif
