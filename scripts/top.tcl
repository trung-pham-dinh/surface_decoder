puts "hello"

# Set top level module
set top logical_bit

# read verilog
read_verilog [ glob D:/Project/Surface_Decoder/src/*.*v ]

set part [get_property PART [current_project]]
puts $part

# synthesize design
synth_design -mode out_of_context -flatten_hierarchy rebuilt -top $top -part $part

# write checkpoint
write_checkpoint -force D:/Project/Surface_Decoder/reports/post_synth.dcp

# generate reports
report_utilization -file D:/Project/Surface_Decoder/reports/post_synth_util.rpt
report_timing_summary -file D:/Project/Surface_Decoder/reports/timing.rpt