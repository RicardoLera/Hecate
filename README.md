## TO-DO

* [X] Write $[log_2(n)-1]$-cycle **generic** FFT
* [X] Re-test correctness
* [ ] Debug step
  &nbsp;
* [ ] Make `src` generic in N
  * [ ] hecate_tb
  * [ ] hecate
  * [ ] hadamard
  * [ ] hadamard_uc
  * [ ] flux_multiplier
  * [ ] flux_inverter
  * [ ] cordic
  * [ ] conv3d
* [ ] Re-test correctness for 7x3x3
* [ ] Debug step
  &nbsp;
* [ ] Implement C3D in python and extract result of 1st conv layer for 1 kernel
* [ ] Implement overlap-add
* [ ] Test vs python using a 128x64x64 image and the same kernel
* [ ] Debug step
  &nbsp;
* [ ] Use software simulation to measure average number of cycles
* [ ] Synthesize for xillinx to measure hardware and power consumption
* [ ] Acquire Virtex-7 (VC709 Evaluation Board)
* [ ] Setup convolution offloading from python to FPGA
* [ ] Run full C3D with and without hecate acceleration to measure performance
* [ ] Hopefully unnecessary debug step
  &nbsp;
* [ ] Write PDS article
  * [ ] Write the rest of the to-do list for the article when you get here
