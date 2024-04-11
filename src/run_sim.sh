#!/bin/bash

ghdl remove

if [ "$1" = "fft" ] ; then
  ghdl -c --std=08 */*.vhd -r fft_8_tb --wave=waveforms/fft.ghw
elif [ "$1" = "had" ] ; then
  ghdl -c --std=08 */*.vhd -r hadamard_tb --wave=waveforms/had.ghw
else
  ghdl -c --std=08 *.vhd */*.vhd -r hecate_tb --wave=waveforms/hecate.ghw
fi
