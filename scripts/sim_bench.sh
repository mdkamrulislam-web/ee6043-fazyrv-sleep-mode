#!/usr/bin/env bash
# Workload simulation (fw/bench.c) on the whole design in xsim.
#   scripts/sim_bench.sh [CHUNKSIZE] [PASSES]     (default 4, 6)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V=/c/AMDDesignTools/2026.1/Vivado/bin
source "$ROOT/scripts/rtl_files.sh"
CS=${1:-4}; NP=${2:-6}
RUN="$ROOT/sim/run_bench_$CS"
bash "$ROOT/fw/build.sh" bench_sim
rm -rf "$RUN"; mkdir -p "$RUN"; cd "$RUN"
cp "$ROOT/fw/firmware_sim.mem" .
printf '`define SIM\n`define TB_CHUNKSIZE %s\n`define TB_PASSES %s\n' $CS $NP > defs.svh
$V/xvlog -sv defs.svh $CORE_RTL \
  "$ROOT"/fazyrv/soc/rtl/fsoc.sv "$ROOT"/fazyrv/soc/rtl/gpio.sv "$ROOT"/fazyrv/soc/rtl/wb_ram.sv \
  $TOP_RTL $GLBL "$ROOT"/sim/tb_bench.sv > xvlog.log
$V/xelab tb_bench glbl -L unisims_ver -debug typical -s tb_bench_snap > xelab.log
$V/xsim tb_bench_snap -R > xsim.log || true
grep -E "PASS|FAIL|CYCLES|RF_RAM" xsim.log
