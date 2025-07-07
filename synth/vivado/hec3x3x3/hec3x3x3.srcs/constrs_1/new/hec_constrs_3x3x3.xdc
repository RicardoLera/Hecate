create_clock -period 8.000 -name VIRTUAL_clk_out1_clk_wiz_0 -waveform {0.000 4.000}

set input_clock       VIRTUAL_clk_out1_clk_wiz_0;
set destination_clock VIRTUAL_clk_out1_clk_wiz_0;

set input_ports  {start reset read_slice {serial_in_img[*]};
set output_ports {load_res ready {serial_out_conv[*]};

set tco_max         0.000;      # Maximum clock to out delay (external device)
set tco_min         0.000;      # Minimum clock to out delay (external device)
set trce_dly_max    0.000;      # Maximum board trace delay
set trce_dly_min    0.000;      # Minimum board trace delay

set tsu             0.000;      # Destination device setup time requirement
set thd             0.000;      # Destination device hold time requirement
set trce_dly_max    0.000;      # Maximum board trace delay
set trce_dly_min    0.000;      # Minimum board trace delay

## Input Delay Constraint
set_input_delay -clock $input_clock -max [expr $tco_max + $trce_dly_max] [get_ports $input_ports];
set_input_delay -clock $input_clock -min [expr $tco_min + $trce_dly_min] [get_ports $input_ports];

# Output Delay Constraint
set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

# derive_pll_clocks -create_base_clocks
# derive_clock_uncertainty