#!/usr/bin/env bash
# Activity-based power analysis of an implemented run.
#   scripts/power_saif.sh <run> [sim_time_us]      (default 3100 us = reset + one 4-bit workload pass)
# 1. Vivado: export the routed design as a functional netlist (the workload is inside its block RAM)
# 2. xsim: simulate the netlist with sim/tb_power.sv and record the switching activity (SAIF)
# 3. Vivado: read the SAIF into the implemented design, report power
# Results: results/<run>/activity.saif, power_saif.rpt, power_saif_hier.rpt, power_saif_summary.txt
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VB=/c/AMDDesignTools/2026.1/Vivado/bin
RUN=$1; T=${2:-3100}
W="$ROOT/sim/power_$RUN"; rm -rf "$W"; mkdir -p "$W"
$VB/vivado -mode batch -nojournal -nolog -source "$ROOT/scripts/power_saif.tcl" -tclargs netlist $RUN > "$W/netlist.log"
cd "$W"
cp /c/AMDDesignTools/2026.1/Vivado/data/verilog/src/glbl.v .
$VB/xvlog netlist.v glbl.v > xvlog.log
$VB/xvlog -sv "$ROOT/sim/tb_power.sv" >> xvlog.log
$VB/xelab tb_power glbl -L unisims_ver -debug typical -s tbp > xelab.log
cat > saif.tcl <<TCL
open_saif activity.saif
log_saif [get_objects -r /tb_power/dut/*]
run ${T}us
close_saif
quit
TCL
t0=$(date +%s)
$VB/xsim tbp -tclbatch saif.tcl > xsim.log
echo "simulated ${T} us in $(( $(date +%s) - t0 )) s"
cp activity.saif "$ROOT/results/$RUN/activity.saif"
$VB/vivado -mode batch -nojournal -nolog -source "$ROOT/scripts/power_saif.tcl" -tclargs report $RUN > "$W/report.log"
cat "$ROOT/results/$RUN/power_saif_summary.txt"
grep -E "matched|Matched|nets" "$ROOT/results/$RUN/read_saif.log" | head -3 || true
