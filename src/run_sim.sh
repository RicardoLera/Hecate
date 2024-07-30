#!/bin/bash
ghdl remove
synth_en=""

if [ "$1" = "dft" ] ; then
  comp_files="hecate_pkg.vhd dft/dft.vhd dft/dft_tb.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd"
  top_module="dft_tb"

elif [ "$1" = "had" ] ; then
  comp_files="hecate_pkg.vhd */*.vhd"
  top_module="hadamard_tb"

elif [ "$1" = "debug" ] ; then
  comp_files="*.vhd */*.vhd"
  top_module="hecate_tb_debug"

elif [ "$1" = "sim" ] ; then
  comp_files="*.vhd */*.vhd"
  top_module="hecate_tb sim"

elif [ "$1" = "synth" ] ; then
  comp_files="*.vhd */*.vhd"
  top_module="hecate_tb synth"
  synth_en="--synth"

else
  printf "ERROR: OPERATION NOT RECOGNIZED\n"
  exit
fi

if [ $synth_en ] ; then
  ghdl --synth --std=08 $comp_files -e $top_module
else
  ghdl $synth_en -c --std=08 -v $comp_files -r $top_module --wave=waveforms/"${top_module%% *}".ghw --ieee-asserts=disable-at-0
fi

#yosys -m ghdl -p "ghdl --std=08 -fsynopsys --latches hecate_pkg.vhd hecate_tb_debug.vhd hecate_tb.vhd hecate.vhd hadamard/hadamard_uc.vhd hadamard/hadamard_tb.vhd hadamard/hadamard.vhd hadamard/flux_multiplier.vhd hadamard/flux_inverter.vhd hadamard/cordic.vhd dft/dft_tb.vhd dft/dft.vhd conv3d.vhd arithmetic/varshiftright.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/adder_carry.vhd -e hecate_tb synth; proc; opt; prep -top hecate_tb synth; write_json teroshdl_yosys_output.json; stat; synth;" &> yosys.txt

#yosys -m ghdl -p "ghdl --std=08 -fsynopsys --latches hecate_pkg.vhd hecate_tb.vhd hecate.vhd hadamard/hadamard_uc.vhd hadamard/hadamard.vhd hadamard/flux_multiplier.vhd hadamard/flux_inverter.vhd hadamard/cordic.vhd dft/dft.vhd conv3d.vhd arithmetic/varshiftright.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/adder_carry.vhd -e hecate_tb; prep -top hecate_tb; write_json yosys_output.json; stat;" &> yosys.txt

#yosys -m ghdl -p "ghdl --std=08 -fsynopsys --latches hecate_pkg.vhd hecate_tb.vhd hecate.vhd hadamard/hadamard_uc.vhd hadamard/hadamard.vhd hadamard/flux_multiplier.vhd hadamard/flux_inverter.vhd hadamard/cordic.vhd dft/dft.vhd conv3d.vhd arithmetic/varshiftright.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/adder_carry.vhd -e hecate_tb; synth -top hecate_tb; write_json yosys_output.json; stat;" &> yosys.txt