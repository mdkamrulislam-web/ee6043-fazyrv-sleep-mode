#!/usr/bin/env bash
# Long run of the board program (fw/firmware.mem) in xsim: scripts/sim_long.sh [steps]  (SLEEP=1 for the sleep design)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V=/c/AMDDesignTools/2026.1/Vivado/bin
source "$ROOT/scripts/rtl_files.sh"
NS=${1:-12}
RUN="$ROOT/sim/run_long_${SLEEP:-0}"
rm -rf "$RUN"; mkdir -p "$RUN"; cd "$RUN"
cp "$ROOT/fw/firmware.mem" .
printf '`define SIM\n`define TB_STEPS %s\n' $NS > defs.svh
$V/xvlog -sv defs.svh $CORE_RTL "$ROOT"/fazyrv/soc/rtl/fsoc.sv "$ROOT"/fazyrv/soc/rtl/gpio.sv "$ROOT"/fazyrv/soc/rtl/wb_ram.sv \
  $TOP_RTL $GLBL "$ROOT"/sim/tb_long.sv > xvlog.log
$V/xelab tb_long glbl -L unisims_ver -s tbl > xelab.log
$V/xsim tbl -R > xsim.log || true
grep -E "LEDs =|FROZEN|fetch|LONG RUN|GPIO" xsim.log
