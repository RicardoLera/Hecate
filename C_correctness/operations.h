#ifndef OPERATIONS_H
#define OPERATIONS_H

    void print_archvar(archvar var);
    void print_archvar_dec(archvar var);
    void print_arch_array(char* name, int j, archvar* arr);
    void print_arch_rec(char* name, archvar arr[9][3]);
    void print_arch_rec_10(char* name, archvar arr[9][3]);
    void print_arch_pol(char* name, archvar arr[9][3]);
    void print_arch_con(char* name, archvar arr[9][2][3], int c);

    archvar archadd(archvar var1, archvar var2);
    archvar archmul(archvar var1, archvar var2);
    archvar archpow(archvar var, int p);
    archvar archshiftR(archvar var, int s);

    void dft(archvar in[8], archvar out[9][3]);
    void cordic_vec(archvar arr[3], int j);
    void cordic_rot(archvar arr[3], int j);
    void p_idft(archvar in[9][3], archvar out[15]);


#endif
