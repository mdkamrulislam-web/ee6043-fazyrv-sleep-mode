# power_saif.tcl - used by scripts/power_saif.sh (activity-based power analysis)
#   step "netlist": export the routed design as a functional Verilog netlist
#   step "report" : read the SAIF activity file and report power
set step [lindex $argv 0]
set run  [lindex $argv 1]
set root [file normalize [file join [file dirname [info script]] ..]]
set out  [file join $root results $run]
set work [file join $root sim power_$run]
open_project [file join $root vivado $run $run.xpr]
open_run impl_1
if {$step eq "netlist"} {
  write_verilog -mode funcsim -force [file join $work netlist.v]
} else {
  read_saif -strip_path tb_power/dut [file join $out activity.saif] -out_file [file join $out read_saif.log]
  # Gated clock (sleep design): Vivado's power tool ignores switching activity on a global clock buffer's
  # enable ("use set_case_analysis instead"), so it cannot model a clock that is on only part of the time.
  # Power-state model: report the power with the clock forced ON (awake) and forced OFF (asleep), and
  # take the measured awake fraction from the SAIF file (net on the BUFGCE CE pin, taking an inverted CE into
  # account). Average power = f_awake * P_awake + (1 - f_awake) * P_asleep  (written to power_states.txt).
  # The gating buffer: a BUFGCE in the RTL, mapped by Vivado onto a BUFGCTRL (enable pin CE0). Find the
  # clock-buffer enable pin that is driven by a real signal (not tied to VCC/GND).
  set cepin ""
  foreach c [get_cells -quiet -hier -filter {REF_NAME == BUFGCE || REF_NAME == BUFGCTRL}] {
    foreach p [get_pins -quiet -of_objects $c -filter {REF_PIN_NAME == CE || REF_PIN_NAME == CE0 || REF_PIN_NAME == CE1}] {
      set pn [get_nets -quiet -of_objects $p]
      if {$pn ne "" && ![string match "*GND*" $pn] && ![string match "*VCC*" $pn]} { set cepin $p; set gce $c }
    }
  }
  if {$cepin ne ""} {
    set saif_lines [split [read [open [file join $out activity.saif]]] "\n"]
    set n [get_nets -of_objects $cepin]
    set leaf [lindex [split $n /] end]
    set inv [get_property -quiet IS_INVERTED $cepin]
    if {$inv eq ""} { set inv 0 }
    set t0 0; set t1 0
    foreach l $saif_lines {
      if {[string match "*($leaf (T0 *" $l] && [regexp {\(T0 (\d+)\) \(T1 (\d+)\)} $l -> t0 t1]} break
    }
    set p1 [expr {double($t1) / ($t0 + $t1)}]
    set f_awake [expr {$inv ? 1.0 - $p1 : $p1}]
    proc dyn {} { set s [report_power -return_string]; regexp {Dynamic \(W\)\s*\|\s*([0-9.<]+)} $s -> v; return $v }
    set on  [expr {$inv ? 0 : 1}]
    set off [expr {$inv ? 1 : 0}]
    set_case_analysis $on $cepin
    report_power -file [file join $out power_awake.rpt]
    set p_awake [dyn]
    set_case_analysis $off $cepin
    report_power -file [file join $out power_asleep.rpt]
    report_power -hierarchical_depth 8 -file [file join $out power_asleep_hier.rpt]
    set p_asleep [dyn]
    set fs [open [file join $out power_states.txt] w]
    puts $fs "gating buffer $gce, enable pin $cepin, net $n (SAIF name $leaf), pin inverted=$inv, net high fraction=$p1"
    puts $fs "f_awake=$f_awake dynamic_awake_w=$p_awake dynamic_asleep_w=$p_asleep"
    if {[string is double -strict $p_awake] && [string is double -strict $p_asleep]} {
      puts $fs "dynamic_average_w=[expr {$f_awake * $p_awake + (1.0 - $f_awake) * $p_asleep}]"
    }
    close $fs
    # Vivado has no remove_case_analysis; a single "always on" report is meaningless for a gated clock,
    # so stop here (the power-state files above are the result for this design).
    exit 0
  }
  report_power -file [file join $out power_saif.rpt]
  report_power -hierarchical_depth 8 -file [file join $out power_saif_hier.rpt]
  report_power -hierarchical_depth 8 -format xml -file [file join $out power_saif.xml]
  set pw [report_power -return_string]
  regexp {Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)} $pw -> ptot
  regexp {Dynamic \(W\)\s*\|\s*([0-9.]+)} $pw -> pdyn
  regexp {Device Static \(W\)\s*\|\s*([0-9.]+)} $pw -> pstat
  regexp {Confidence Level\s*\|\s*(\S+)} $pw -> conf
  set f [open [file join $out power_saif_summary.txt] w]
  puts $f "run=$run power_total_w=$ptot power_dynamic_w=$pdyn power_static_w=$pstat confidence=$conf"
  foreach k {Clocks {Slice Logic} Signals {Block RAM} I/O} {
    if {[regexp "\|\s*$k\s*\|\s*(\[<0-9.\]+)" $pw -> v]} { puts $f "  [string map {{ } _} $k]_w=$v" }
  }
  close $f
}
