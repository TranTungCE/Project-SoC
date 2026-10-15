# Simulation Script for Vivado Simulator (xsim)
set workDir [pwd]
set outputDir ./sim_output
file mkdir $outputDir

create_project -in_memory -part xc7z020clg400-1
set_property include_dirs [list ./src] [current_fileset]

read_verilog -sv ./src/DatapathPipelined.sv
read_verilog -sv ./src/tb_DatapathPipelined.sv

set_property top tb_DatapathPipelined [current_fileset]

# Launch simulation
launch_simulation -mode behavioral -simset sim_1

# Run for 2000 ns
run 2000 ns

exit
