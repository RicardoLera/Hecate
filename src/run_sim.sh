#!/bin/bash

ghdl remove
ghdl -a --std=08 \
    arithmetic/*.vhd                    \
    fft/fft_8.vhd                       \
    cordic/cordic.vhd                   \
    hadamard/hadamard.vhd               \
    hadamard/hadamard_uc.vhd            \
    hadamard/flux_inverter.vhd          \
    hadamard/flux_multiplier.vhd
    

if [ "$1" = "had" ] ; then
    ghdl -a --std=08 hadamard/hadamard_tb.vhd
    ghdl -e --std=08 hadamard
    ghdl -r --std=08 hadamard_tb --wave=waveforms/had.ghw
else
    ghdl -a --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP_tb.vhd
    ghdl -e --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP
    ghdl -r --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP_tb --wave=waveforms/poly_mvp.ghw
fi
