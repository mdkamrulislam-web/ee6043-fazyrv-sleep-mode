# -----------------------------------------------------------------------------
# build.tcl - full Vivado flow for top_pynqz2: synthesis -> implementation ->
# bitstream, then the reports used in the project report.
#
#   vivado -mode batch -source scripts/build.tcl -tclargs <run> <chunksize> <period_ns> [<synth_strategy> <impl_strategy>]
#
# Example (baseline of the report):
#   vivado -mode batch -source scripts/build.tcl -tclargs base 4 8.0 Flow_PerfOptimized_high Performance_ExplorePostRoutePhysOpt
# SLEEP=1 (environment variable) builds the sleep design instead.
#
# Makes a normal Vivado project in vivado/<run>/<run>.xpr (open it in the GUI
# for screenshots) and copies the reports to results/<run>/.
# -----------------------------------------------------------------------------

set run    [lindex $argv 0]
set cs     [lindex $argv 1]
set period [lindex $argv 2]
set sstrat [expr {[llength $argv] > 3 ? [lindex $argv 3] : "Vivado Synthesis Defaults"}]
set istrat [expr {[llength $argv] > 4 ? [lindex $argv 4] : "Vivado Implementation Defaults"}]

set root [file normalize [file join [file dirname [info script]] ..]]
set proj [file join $root vivado $run]
set out  [file join $root results $run]
file mkdir $out

create_project -force $run $proj -part xc7z020clg400-1
set_property target_language Verilog [current_project]

# Sources: FazyRV core, the fsoc SoC, the board wrapper and the program
set core_rtl [glob $root/fazyrv/rtl/*.sv $root/fazyrv/rtl/*.v]
add_files $core_rtl
add_files [list $root/fazyrv/soc/rtl/fsoc.sv $root/fazyrv/soc/rtl/gpio.sv $root/fazyrv/soc/rtl/wb_ram.sv]
# SLEEP=1 (environment variable): sleep design (gated-clock top level, fsoc_sleep, sleep_ctrl)
if {[info exists ::env(SLEEP)] && $::env(SLEEP) eq "1"} {
  add_files [list $root/src/sleep/top_pynqz2.sv $root/src/sleep/fsoc_sleep.sv $root/src/sleep/sleep_ctrl.sv]
  puts "SLEEP_DESIGN=1"
} else {
  add_files $root/src/top_pynqz2.sv
}
add_files $root/fw/firmware.mem
set_property top top_pynqz2 [current_fileset]
# DIAG=1 (environment variable): board-debug wrapper with clock heartbeat and reset indicator
if {[info exists ::env(DIAG)] && $::env(DIAG) in {1 2 3 4}} {
  # DIAG=2: same, but the processor runs at 100 MHz from an MMCM
  # DIAG=3: 125 MHz, plus stretched reset indicator and processor-alive indicator
  # DIAG=4: like 3, but the processor runs at 25 MHz from an MMCM
  add_files $root/src/diag/[dict get {1 top_pynqz2_diag.sv 2 top_pynqz2_diag100.sv 3 top_pynqz2_diag3.sv 4 top_pynqz2_diag25.sv} $::env(DIAG)]
  set f [lindex [get_files *top_pynqz2_diag*.sv] 0]
  set_property file_type SystemVerilog [get_files *top_pynqz2_diag*.sv]
  add_files -fileset constrs_1 $root/src/diag/pynqz2_diag.xdc
  set_property top top_pynqz2_diag [current_fileset]
  puts "DIAG_TOP=1"
}
set_property generic "CHUNKSIZE=$cs" [current_fileset]

# Constraints: fixed pins + the clock period for this run
add_files -fileset constrs_1 $root/constr/pynqz2_pins.xdc
set tx [file join $proj timing.xdc]
set f [open $tx w]
puts $f "## Clock constraint for run '$run'"
puts $f "create_clock -name sysclk -period $period \[get_ports sysclk\]"
close $f
add_files -fileset constrs_1 $tx
# UNC=<ns> (environment variable): extra setup uncertainty = over-constraint, so the tools leave that much margin.
# It stays in the timing reports, so a reported WNS >= 0 means "met with <ns> to spare".
if {[info exists ::env(UNC)] && $::env(UNC) ne ""} {
  set f [open $tx a]
  puts $f "set_clock_uncertainty -setup $::env(UNC) \[get_clocks sysclk\]"
  close $f
  puts "EXTRA_UNCERTAINTY=$::env(UNC)"
}

# Simulation set: the system test bench (so it can be run from the GUI)
add_files -fileset sim_1 $root/sim/tb_top.sv
set_property top tb_top [get_filesets sim_1]

set_property strategy $sstrat [get_runs synth_1]
set_property strategy $istrat [get_runs impl_1]

set t0 [clock seconds]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synthesis failed" }
set t1 [clock seconds]

open_run synth_1 -name synth_1
report_utilization    -file $out/post_synth_utilization.rpt
report_timing_summary -file $out/post_synth_timing_summary.rpt
close_design

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "implementation failed" }
set t2 [clock seconds]

open_run impl_1
report_timing_summary -max_paths 10 -report_unconstrained -file $out/timing_summary.rpt
report_timing -max_paths 5 -nworst 1 -path_type full -input_pins -file $out/critical_paths.rpt
report_utilization -file $out/utilization.rpt
report_utilization -hierarchical -hierarchical_depth 4 -file $out/utilization_hier.rpt
report_power -file $out/power.rpt
report_drc -file $out/drc.rpt
report_methodology -file $out/methodology.rpt
report_clock_utilization -file $out/clock_utilization.rpt

source [file join $root scripts summary.tcl]

file copy -force [glob $proj/$run.runs/impl_1/*.bit] $out/top_pynqz2_$run.bit
