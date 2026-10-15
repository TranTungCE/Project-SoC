# Run and dump VCD waveform
open_vcd sim_waveform.vcd
log_vcd [get_objects -r /tb_DatapathPipelined/*]
run all
flush_vcd
close_vcd
exit
