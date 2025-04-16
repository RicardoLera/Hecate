#!/bin/bash

# Synthesis relies on 3 external softwares: ghdl, yosys and ghdl-yosys-plugin
# The following are the respective versions of these programs under which the first synthesis test was successful:

# yosys --version
# Yosys 0.51+162 (git sha1 c261da4e7, g++ 14.2.1 -march=x86-64 -mtune=generic -O2 -fno-plt -fexceptions -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -ffile-prefix-map=/home/seth/.cache/yay/yosys-nightly/src=/usr/src/debug/yosys-nightly -flto=auto -fPIC -O3)
# 
# pacman -Q yosys
# yosys-nightly 1:20250409_v0.51_166_gc261da4e7-1

# ghdl --version
# GHDL 6.0.0-dev (b6.0.0.r62.g57dc78c76) [Dunoon edition]
#  Compiled with GNAT Version: 14.2.1 20250207
#  GCC 12.4.0 code generator
# 
# pacman -Q ghdl
# ghdl-gcc-git 6.0.0dev.r10015.g57dc78c76-1

# pacman -Q ghdl-yosys-plugin
# ghdl-yosys-plugin-git r231.8c29f2c-1
# 
# github.com/ghdl/ghdl-yosys-plugin/
# Exact commit at test time -> 8c29f2cc7cc3b8c979acd02f543d25f321b55c30

ghdl remove

if [ "$1" = "synth" ] ; then
  
  comp_files="hecate_pkg.vhd hecate_oa_tb.vhd hecate_oa.vhd hecate.vhd hadamard/hadamard_uc.vhd hadamard/hadamard.vhd hadamard/flux_multiplier.vhd hadamard/flux_inverter.vhd hadamard/cordic.vhd fft/fft.vhd arithmetic/varshiftright.vhd arithmetic/b25_cmul.vhd arithmetic/b25_add.vhd arithmetic/adder_carry.vhd arithmetic/b25_butterfly.vhd arithmetic/b25_wmul.vhd"

  family="xc${2:-"7"}"

  yosys -m ghdl -p \
    "ghdl --std=08 -fsynopsys --latches $comp_files -e hecate_oa_tb; synth_xilinx -top hecate_oa_tb -family $family -flatten; json -o yosys_out/$family.json" \
  2>&1 | tee >(tail -n 128 > yosys_out/"$family"_synth_log_tail.txt)
  # &> yosys_out/"$family".txt

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

  elif [ "$1" = "hec_debug" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_tb_debug"

  elif [ "$1" = "hec" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_tb sim"

  elif [ "$1" = "hec_oa_debug" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_oa_tb_debug"

  elif [ "$1" = "hec_oa" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_oa_tb sim"

  else
    printf "ERROR: OPERATION NOT RECOGNIZED\n"
    exit
  fi

  #Doesn't work in gcc version. Go back to analyze->elab
  #ghdl -c --std=08 -v $comp_files -e --ieee-asserts=disable-at-0 --wave=waveforms/"${top_module%% *}".ghw hecate_oa_tb 

fi