# gui_sleep.tcl - screenshots for the sleep-mode chapter (runs sleep_o_pw and busy_o_pw).
#   vivado -mode gui -source scripts/gui_sleep.tcl        (do not touch mouse/keyboard while it runs)
# Power is shown WITH the activity file (read_saif). For the sleep design the gated clock is forced
# on (awake) and off (asleep) with set_case_analysis on the clock-buffer enable, as in power_saif.tcl.
# Vivado maps the BUFGCE onto a BUFGCTRL with an inverted CE0, so value 0 = clock on, 1 = clock off.
set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $root report shots]
set logf [open [file join $root report shots gui_sleep.log] w]
proc log {m} { global logf; puts $logf $m; flush $logf }
proc shot {name {d 4}} {
  global root
  log [exec powershell -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts capture.ps1] [file join $root report shots $name.png] $d]
}
proc ps {args} { global root; exec powershell -NoProfile -ExecutionPolicy Bypass -File [file join $root scripts click.ps1] {*}$args }
proc open_impl {run} {
  global root
  catch {close_project}
  open_project $root/vivado/$run/$run.xpr
  open_run impl_1 -name impl_1
  read_saif -strip_path tb_power/dut $root/results/$run/activity.saif
}
proc cepin {} {
  set p [get_pins -quiet u_bufgce/CE0]
  if {$p eq ""} { set p [get_pins -quiet u_bufgce/CE] }
  log "enable pin: $p inverted=[get_property -quiet IS_INVERTED $p]"
  return $p
}
# Runs and screenshot prefix can be changed with environment variables SLEEP_RUN, BUSY_RUN and PREFIX.
proc envor {k d} { if {[info exists ::env($k)] && $::env($k) ne ""} { return $::env($k) } { return $d } }
set SR [envor SLEEP_RUN sleep_o_pw]; set BR [envor BUSY_RUN busy_o_pw]; set PF [envor PREFIX ""]
set steps {}
lappend steps [list open_impl $SR]
lappend steps [list eval "report_timing_summary -max_paths 10 -name ts_sleep; shot ${PF}sleep_timing 5"]
# built with a 7.5 ns target (tighter-target trick); show timing against the real 8 ns board clock
lappend steps [list eval "create_clock -name sysclk -period 8.000 \[get_ports sysclk\]; report_timing_summary -max_paths 10 -name ts_sleep_8ns; shot ${PF}sleep_timing_8ns 5"]
lappend steps [list eval "create_clock -name sysclk -period 7.5 \[get_ports sysclk\]"]
lappend steps [list eval "report_utilization -name util_sleep; shot ${PF}sleep_util 5"]
lappend steps [list eval {set_case_analysis 0 [cepin]; report_power -name pw_awake; after 1500; ps 1875 716 0; shot ${PF}sleep_power_awake 5}]
lappend steps [list eval {set_case_analysis 1 [cepin]; report_power -name pw_asleep; after 1500; shot ${PF}sleep_power_asleep 5}]
lappend steps [list open_impl $BR]
lappend steps [list eval "report_power -name pw_busy; after 1500; ps 1875 716 0; shot ${PF}busy_power 5"]
lappend steps {log DONE; close $logf; exit}
proc run_next {} {
  global steps
  if {[llength $steps] == 0} return
  set s [lindex $steps 0]; set steps [lrange $steps 1 end]
  if {[catch {uplevel #0 $s} err]} { log "STEP FAILED: [string range $s 0 90] -> $err" }
  after 1500 run_next
}
after 2000 run_next
