#!/bin/bash
ghdl remove

if [ "$1" = "synth" ] ; then
  
  comp_files="hecate_pkg.vhd hecate.vhd hadamard/hadamard_uc.vhd hadamard/hadamard.vhd hadamard/flux_multiplier.vhd hadamard/flux_inverter.vhd hadamard/cordic.vhd dft/dft.vhd arithmetic/varshiftright.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/adder_carry.vhd"

  family="xc${2:-"7"}"

  yosys -m ghdl -p \
    "ghdl --std=08 -fsynopsys --latches $comp_files -e hecate; synth_xilinx -top hecate -family $family -flatten; json -o yosys_out/$family.json" \
  &> yosys_out/"$family".txt

else

  if [ "$1" = "lsp" ] ; then
    comp_files="debug_lsp/*.vhd"
    top_module="lsp_tb"

  elif [ "$1" = "dft" ] ; then
    comp_files="hecate_pkg.vhd dft/dft.vhd dft/dft_tb.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd"
    top_module="dft_tb"
  
  elif [ "$1" = "fft" ] ; then
    comp_files="hecate_pkg.vhd fft/fft.vhd fft/fft_tb.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/b25_wmul.vhd arithmetic/b25_butterfly.vhd"
    top_module="fft_tb"

  elif [ "$1" = "had" ] ; then
    comp_files="hecate_pkg.vhd */*.vhd"
    top_module="hadamard_tb"

  elif [ "$1" = "debug" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_tb_debug"

  elif [ "$1" = "hec" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_tb sim"

  else
    printf "ERROR: OPERATION NOT RECOGNIZED\n"
    exit
  fi

  ghdl -c --std=08 -v $comp_files -r $top_module --wave=waveforms/"${top_module%% *}".ghw --ieee-asserts=disable-at-0

fi