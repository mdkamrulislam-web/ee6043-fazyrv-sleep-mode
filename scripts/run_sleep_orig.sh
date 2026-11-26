#!/usr/bin/env bash
# Before/after study of the sleep mode: builds the busy-wait and sleep designs and runs the
# activity-based power analysis (with the power-state model for the gated clock). One Vivado at a time.
#   busy_o_pw    busy-wait LED program, normal design            (8 ns)
#   sleep_o_pw   sleeping LED program, sleep design               (7.5 ns target, re-timed at 8 ns in the report)
#   sleep_o_board sleeping LED program for the board (~0.77 s/step) (7.5 ns target)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
VB=/c/AMDDesignTools/2026.1/Vivado/bin/vivado
S="Flow_PerfOptimized_high Performance_ExplorePostRoutePhysOpt"
build() { # run fw sleep period
  bash fw/build.sh $2 > /dev/null
  SLEEP=$3 $VB -mode batch -nojournal -log results/$1_vivado.log -source scripts/build.tcl -tclargs $1 4 $4 $S > /dev/null 2>&1
  echo "$1: $(sed -n 2p results/$1/summary.txt) | sleep-design lines: $(grep -c '^SLEEP_DESIGN=1' results/$1_vivado.log)"
}
build busy_o_pw counter_pw 0 8.0
build sleep_o_pw sleep_pw 1 7.5
build sleep_o_board sleep 1 7.5
bash fw/build.sh > /dev/null      # restore the workload as fw/firmware.mem
bash scripts/power_saif.sh busy_o_pw 3300 | head -1
bash scripts/power_saif.sh sleep_o_pw 3300 | head -1 || true
cat results/sleep_o_pw/power_states.txt
echo STUDY_DONE
