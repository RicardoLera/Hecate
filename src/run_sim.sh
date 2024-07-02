#!/bin/bash
ghdl remove

if [ "$1" = "dft" ] ; then
  comp_files="hecate_pkg.vhd dft/dft.vhd dft/dft_tb.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd"
  top_module="dft_tb"
elif [ "$1" = "had" ] ; then
  comp_files="hecate_pkg.vhd */*.vhd"
  top_module="hadamard_tb"
elif [ "$1" = "debug" ] ; then
  comp_files="*.vhd */*.vhd"
  top_module="hecate_tb_debug"
else
  comp_files="*.vhd */*.vhd"
  top_module="hecate_tb"
fi

ghdl -c --std=08 $comp_files -r "$top_module" --wave=waveforms/"$top_module".ghw --ieee-asserts=disable-at-0

