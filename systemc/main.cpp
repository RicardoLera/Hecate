#include "systemc.h"

typedef struct archvar {
    unsigned int aux: 9;
    signed int core: 16;
} archvar;

SC_MODULE(PROCESS) {
    sc_in<archvar> in[8];
    sc_out<archvar> out[9][2];


    SC_CTOR(PROCESS) {
        SC_METHOD(dft);
    }


};

int sc_main(int argc, char* argv[]) {

    return 0;
}





//archvar in[8], archvar out[9][2]
