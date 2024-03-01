#!/bin/bash

ghdl remove
ghdl -a --std=02 -P=intel --ieee=synopsys -frelaxed \
    auxiliaries/*.vhd                   \
    hadamard/hadamard.vhd               \
    hadamard/hadamard_uc.vhd            \
    hadamard/flux_inverter.vhd          \
    hadamard/flux_multiplier.vhd        \
    hadamard/varshiftright.vhd          \
    cordic/cordic.vhd                   \
    mul_cos/mul_cos_22.vhd              \
    mul_cos/mul_cos_45.vhd              \
    mul_cos/mul_cos_67.vhd              \
    mul_cos/mul_cos_simm.vhd            \
    fft/fft_8.vhd                       \
    Polyanna_MVP.vhd

if [ "$1" = "had" ] ; then
    ghdl -a --std=02 -P=intel --ieee=synopsys -frelaxed hadamard/hadamard_tb.vhd
    ghdl -e --std=02 -P=intel --ieee=synopsys -frelaxed hadamard
    ghdl -r --std=02 -P=intel --ieee=synopsys -frelaxed hadamard_tb --wave=waveforms/had.ghw
else
    ghdl -a --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP_tb.vhd
    ghdl -e --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP
    ghdl -r --std=02 -P=intel --ieee=synopsys -frelaxed Polyanna_MVP_tb --wave=waveforms/poly_mvp.ghw
fi
