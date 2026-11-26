#!/usr/bin/env bash
# System simulation of top_pynqz2 in the Vivado simulator (xsim).
#   scripts/sim_top.sh [CHUNKSIZE]   (default 8)
# Output: sim/run_top_<CHUNKSIZE>/xsim.log and a waveform database (tb_top.wdb).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V=/c/AMDDesignTools/2026.1/Vivado/bin
source "$ROOT/scripts/rtl_files.sh"
CS=${1:-8}
RUN="$ROOT/sim/run_top_$CS"

bash "$ROOT/fw/build.sh" ${FW_SIM:-counter_sim}
rm -rf "$RUN"; mkdir -p "$RUN"; cd "$RUN"
cp "$ROOT/fw/firmware_sim.mem" .

printf '`define SIM\n`define TB_CHUNKSIZE %s\n' $CS > defs.svh
if [ "${SLEEP:-0}" = "1" ]; then echo '`define TB_SLEEP' >> defs.svh; fi
$V/xvlog -sv defs.svh \
  $CORE_RTL \
  "$ROOT"/fazyrv/soc/rtl/fsoc.sv "$ROOT"/fazyrv/soc/rtl/gpio.sv "$ROOT"/fazyrv/soc/rtl/wb_ram.sv \
  $TOP_RTL $GLBL "$ROOT"/sim/tb_top.sv > xvlog.log
$V/xelab tb_top glbl -L unisims_ver -debug typical -s tb_top_snap > xelab.log
$V/xsim tb_top_snap -R -wdb tb_top.wdb > xsim.log || true
grep -E "PASS|FAIL|LEDs start|SW0=|Reset in|CPU clock" xsim.log
