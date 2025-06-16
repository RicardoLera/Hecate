create_clock -period 8.000 -name clock -waveform {0.000 4.000} [get_ports clock]

set input_clock         clock;      # Name of input clock
set input_clock_period  8.000;      # Period of input clock
set dv_bre              0.000;      # Data valid before the rising clock edge
set dv_are              0.000;      # Data valid after the rising clock edge

# Input Delay Constraint
set_input_delay -clock $input_clock -max [expr $input_clock_period - $dv_bre] [get_ports {rom_serial_i[*]}];
set_input_delay -clock $input_clock -min $dv_are                              [get_ports {rom_serial_i[*]}];
set_input_delay -clock $input_clock -max [expr $input_clock_period - $dv_bre] [get_ports {rom_serial_k[*]}];
set_input_delay -clock $input_clock -min $dv_are                              [get_ports {rom_serial_k[*]}];
set_input_delay -clock $input_clock -max [expr $input_clock_period - $dv_bre] [get_ports reset];
set_input_delay -clock $input_clock -min $dv_are                              [get_ports reset];
set_input_delay -clock $input_clock -max [expr $input_clock_period - $dv_bre] [get_ports start];
set_input_delay -clock $input_clock -min $dv_are                              [get_ports start];

set destination_clock clock;            # Name of destination clock
set tsu               0.000;            # Destination device setup time requirement
set thd               0.000;            # Destination device hold time requirement
set trce_dly_max      0.000;            # Maximum board trace delay
set trce_dly_min      0.000;            # Minimum board trace delay

# Output Delay Constraint
set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports {ram_serial[*]}];
set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports {ram_serial[*]}];
set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports ready];
set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports ready];