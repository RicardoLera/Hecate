#ifndef VAR_H
#define VAR_H

#include <stdint.h>

    typedef struct archvar {
        uint8_t  sign:  1;
        uint8_t  pre:   8;
        uint16_t post: 16;
    } archvar;

    extern archvar twiddle_arr[16][2];
    extern archvar arctan[24];

#endif
