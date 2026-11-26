# board_status.tcl - is the FPGA still configured? (DONE pin and user design status over JTAG)
open_hw_manager
connect_hw_server -allow_non_jtag
set t [lindex [get_hw_targets -quiet] 0]
if {$t eq ""} { puts "STATUS: NO BOARD"; exit 1 }
open_hw_target $t
set dev [lindex [get_hw_devices -quiet xc7z020*] 0]
refresh_hw_device -quiet $dev
puts "STATUS: DONE=[get_property REGISTER.CONFIG_STATUS.BIT14_DONE_PIN $dev]"
close_hw_target
