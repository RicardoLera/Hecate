#!/bin/bash

ghdl remove

if [ "$1" = "dft" ] ; then
  ghdl -c --std=08 hecate_pkg.vhd dft/dft.vhd dft/dft_tb.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd  -r dft_tb --wave=waveforms/dft.ghw
elif [ "$1" = "had" ] ; then
  ghdl -c --std=08 */*.vhd -r hadamard_tb --wave=waveforms/had.ghw
else
  ghdl -c --std=08 *.vhd */*.vhd -r hecate_tb --wave=waveforms/hecate.ghw
fi
