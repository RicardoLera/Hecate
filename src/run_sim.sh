#!/bin/bash

# Synthesis relies on 3 external softwares: ghdl, yosys and ghdl-yosys-plugin
# The following are the respective versions of these programs under which the first synthesis test was successful:

# yosys --version
# Yosys 0.51+162 (git sha1 c261da4e7, g++ 14.2.1 -march=x86-64 -mtune=generic -O2 -fno-plt -fexceptions -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -ffile-prefix-map=/home/seth/.cache/yay/yosys-nightly/src=/usr/src/debug/yosys-nightly -flto=auto -fPIC -O3)
# 
# pacman -Q yosys
# yosys-nightly 1:20250409_v0.51_166_gc261da4e7-1
# Exact commit -> c261da4e796c4096c7d36c6132a854c975f38c1b

# ghdl --version
# GHDL 6.0.0-dev (b6.0.0.r62.g57dc78c76) [Dunoon edition]
#  Compiled with GNAT Version: 14.2.1 20250207
#  GCC 12.4.0 code generator
# 
# pacman -Q ghdl
# ghdl-gcc-git 6.0.0dev.r10015.g57dc78c76-1
# Release -> https://github.com/ghdl/ghdl/releases/download/v5.0.1/ghdl-gcc-5.0.1-ubuntu24.04-x86_64.tar.gz

# pacman -Q ghdl-yosys-plugin
# ghdl-yosys-plugin-git r231.8c29f2c-1
# 
# github.com/ghdl/ghdl-yosys-plugin/
# Exact commit -> 8c29f2cc7cc3b8c979acd02f543d25f321b55c30

ghdl remove

if [ "$1" = "synth" ] ; then
  
  comp_files="*.vhd */*.vhd"
  family="xc${2:-"7"}"

  yosys -m ghdl -p \
    "ghdl --std=08 -fsynopsys --latches $comp_files -e hecate_tb; synth_xilinx -top hecate_tb -family $family -flatten; json -o yosys_out/$family.json" \
  2>&1 | tee >(tail -n 128 > yosys_out/"$family"_synth_log_tail.txt)
  # &> yosys_out/"$family".txt

else
  
  if [ "$1" = "fft" ] ; then
    comp_files="auxiliary/hecate_pkg.vhd auxiliary/function_rom.vhd fft/*.vhd"
    top_module="fft_tb sim"

  elif [ "$1" = "had" ] ; then
    comp_files="auxiliary/hecate_pkg.vhd hadamard/*.vhd"
    top_module="hadamard_tb sim"

  elif [ "$1" = "hec" ] ; then
    comp_files="*.vhd */*.vhd"
    top_module="hecate_tb sim"

  else
    printf "ERROR: OPERATION NOT RECOGNIZED\n"
    exit
  fi

  ghdl -i --std=08 $comp_files
  ghdl -m --std=08 $top_module
  ghdl -e --std=08 $top_module
  ghdl -r --std=08 $top_module --max-stack-alloc=4096 --asserts=disable-at-0 --wave=waveforms/"${top_module%% *}".ghw

  rm *.o
  rm "$(echo $top_module | awk '{print $1;}')"-"$(echo $top_module | awk '{print $2;}')"
fi