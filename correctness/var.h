#include <inttypes.h>
#ifndef VAR_H
#define VAR_H

  typedef struct archvar {
      bool     sign:  1;
      uint8_t  pre:   8;
      uint16_t post: 16;
  } archvar;

  extern archvar twiddle_arr[32][2];
  extern archvar arctan[24];

#endif
