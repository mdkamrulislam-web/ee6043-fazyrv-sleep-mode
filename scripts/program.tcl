# program.tcl - find the PYNQ-Z2 over JTAG and (optionally) load a bitstream.
#   vivado -mode batch -source scripts/program.tcl                 (just list the board)
#   vivado -mode batch -source scripts/program.tcl -tclargs <file.bit>
open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets -quiet]
puts "TARGETS: $targets"
if {$targets eq ""} { puts "NO BOARD FOUND"; exit 1 }
open_hw_target [lindex $targets 0]
set dev [lindex [get_hw_devices -quiet xc7z020*] 0]
puts "DEVICES: [get_hw_devices]"
if {[llength $argv] > 0 && $dev ne ""} {
  current_hw_device $dev
  set_property PROGRAM.FILE [lindex $argv 0] $dev
  program_hw_devices $dev
  puts "PROGRAMMED: [lindex $argv 0] DONE=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
}
close_hw_target
