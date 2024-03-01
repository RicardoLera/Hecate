#!/bin/bash

ghdl remove
ghdl -a --std=02 \
    arithmetic/b25_cmul.vhd             \
    arithmetic/b25_add.vhd              \
    fft/fft_8.vhd                       \
    fft/fft_8_tb.vhd
ghdl -e --std=02 fft_8
ghdl -r --std=02 fft_8_tb --wave=waveforms/fft.ghw
