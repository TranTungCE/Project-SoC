# Vivado Batch Script to run Simulation, Synthesis, Implementation, and generate Reports
# Target board: Digilent Arty-Z7-20 (part xc7z020clg400-1)

set workDir [pwd]
set outputDir ./vivado_output
file mkdir $outputDir

puts "=========================================================="
puts "  STARTING VIVADO WORKFLOW FOR PIPELINED RISC-V SOC      "
puts "=========================================================="

# 1. Create In-Memory Project
create_project -in_memory -part xc7z020clg400-1

# 2. Add HDL source files
set_property include_dirs [list ./src ./src/system] [current_fileset]
read_verilog -sv ./src/DatapathPipelined.sv
read_verilog -sv ./src/system/RiscvSystem.sv
read_verilog -sv ./src/system/OledDevice.sv
read_verilog ./src/system/debouncer.v
read_verilog ./src/system/delay_ms.v
read_verilog ./src/system/mmcm.v
read_verilog ./src/system/OLEDCtrl.v
read_verilog ./src/system/SpiCtrl.v

# 3. Add IP blocks
read_ip ./src/system/ip/charLib/charLib.xci
read_ip ./src/system/ip/init_sequence_rom/init_sequence_rom.xci
read_ip ./src/system/ip/pixel_buffer/pixel_buffer.xci
upgrade_ip [get_ips]
generate_target all [get_ips]

# 4. Add constraint file
read_xdc ./src/system/Arty-Z7-20.xdc

# 5. Synthesize Design
puts "--- Running Synthesis for RiscvSystem ---"
synth_design -top RiscvSystem -part xc7z020clg400-1

# 6. Generate Synthesis Reports
puts "--- Generating Synthesis Reports ---"
report_utilization -file $outputDir/post_synth_utilization.txt
report_timing_summary -file $outputDir/post_synth_timing_summary.txt

# 7. Place and Route (Implementation)
puts "--- Running Optimization & Place-and-Route ---"
opt_design
place_design
route_design

# 8. Generate Implementation Reports
puts "--- Generating Implementation Reports ---"
report_utilization -file $outputDir/post_route_utilization.txt
report_timing_summary -file $outputDir/post_route_timing_summary.txt
report_drc -file $outputDir/post_route_drc.txt

# 9. Generate Bitstream for Arty-Z7-20
puts "--- Generating Bitstream ---"
write_bitstream -force $outputDir/RiscvSystem_ArtyZ7.bit

puts "=========================================================="
puts "  VIVADO WORKFLOW COMPLETED SUCCESSFULLY!                 "
puts "=========================================================="
exit
