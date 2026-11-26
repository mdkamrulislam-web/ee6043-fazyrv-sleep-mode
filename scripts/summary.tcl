# summary.tcl - writes results/<run>/summary.txt from the open implemented design.
# Sourced by build.tcl; on its own:
#   vivado -mode batch -source scripts/summary.tcl -tclargs <run> <period_ns>
if {![info exists run]} {
  set run    [lindex $argv 0]
  set period [lindex $argv 1]
  set cs ?; set sstrat ?; set istrat ?; set t0 0; set t1 0; set t2 0
  set root [file normalize [file join [file dirname [info script]] ..]]
  set out  [file join $root results $run]
  open_project [file join $root vivado $run $run.xpr]
  open_run impl_1
  set cs [lindex [split [get_property generic [current_fileset]] =] 1]
  set sstrat [get_property strategy [get_runs synth_1]]
  set istrat [get_property strategy [get_runs impl_1]]
}
# --- One-line summary --------------------------------------------------------
set wns  [get_property SLACK [lindex [get_timing_paths -max_paths 1 -nworst 1 -setup] 0]]
set whs  [get_property SLACK [lindex [get_timing_paths -max_paths 1 -nworst 1 -hold] 0]]
set fmax [format %.1f [expr {1000.0 / ($period - $wns)}]]
proc used {name} {
  set rows [split [report_utilization -return_string] "\n"]
  foreach r $rows {
    if {[regexp "^\\|\\s*$name\\s*\\|\\s*(\[0-9.\]+)" $r -> v]} { return $v }
  }
  return "?"
}
set luts [used "Slice LUTs"]
set ffs  [used "Slice Registers"]
set bram [used "Block RAM Tile"]
set lutram [used "LUT as Memory"]
set slices [used "Slice"]
set pw [report_power -return_string]
regexp {Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)} $pw -> ptot
regexp {Dynamic \(W\)\s*\|\s*([0-9.]+)} $pw -> pdyn
regexp {Device Static \(W\)\s*\|\s*([0-9.]+)} $pw -> pstat

# Critical path: start and end points
set cp [lindex [get_timing_paths -max_paths 1 -nworst 1 -setup] 0]
set cps [get_property STARTPOINT_PIN $cp]
set cpe [get_property ENDPOINT_PIN $cp]
set lvl [get_property LOGIC_LEVELS $cp]
set dly [get_property DATAPATH_DELAY $cp]

set f [open $out/summary.txt w]
puts $f "run=$run chunksize=$cs period_ns=$period synth_strategy=\"$sstrat\" impl_strategy=\"$istrat\""
puts $f "wns_ns=$wns whs_ns=$whs fmax_mhz=$fmax"
puts $f "luts=$luts lut_as_memory=$lutram ffs=$ffs slices=$slices bram_tiles=$bram"
puts $f "power_total_w=$ptot power_dynamic_w=$pdyn power_static_w=$pstat"
puts $f "critical_path: $cps -> $cpe  logic_levels=$lvl datapath_ns=$dly"
puts $f "time_synth_s=[expr {$t1-$t0}] time_impl_s=[expr {$t2-$t1}]"
close $f

puts "SUMMARY [read [open $out/summary.txt]]"
