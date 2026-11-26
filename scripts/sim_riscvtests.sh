#!/usr/bin/env bash
# Core check: run FazyRV's own riscv-tests (40 RV32I instruction tests) in xsim.
#   scripts/sim_riscvtests.sh [CHUNKSIZE] [RFTYPE]     (default 8 BRAM_BP)
# Each test prints "<name>..OK"; the run ends with "DONE" (pass) or stops on "ERR".
# Output: sim/run_rvtests_<CHUNKSIZE>/xsim.log
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V=/c/AMDDesignTools/2026.1/Vivado/bin
source "$ROOT/scripts/rtl_files.sh"
export PATH="/c/AMDDesignTools/2026.1/gnu/riscv/nt/bin:$PATH"
P=riscv64-unknown-elf-
CS=${1:-8}
RF=${2:-BRAM_BP}
RUN="$ROOT/sim/run_rvtests_$CS"
S="$ROOT/fazyrv/sim"

rm -rf "$RUN"; mkdir -p "$RUN/firmware" "$RUN/obj"; cd "$RUN"

# 1. Build the test program (start.S calls every test in turn).
${P}gcc -c -mabi=ilp32 -march=rv32i -o obj/start.o "$S/firmware/start.S"
for s in "$S"/tests/*.S; do
  n=$(basename "$s" .S)
  ${P}gcc -c -DINT_CSR=0 -mabi=ilp32 -march=rv32i_zicsr -I"$S/tests" -o obj/$n.o \
      -DTEST_FUNC_NAME=$n "-DTEST_FUNC_TXT=\\\"$n\\\"" -DTEST_FUNC_RET=${n}_ret "$s"
done
${P}gcc -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -o firmware/firmware.elf \
    -Wl,--build-id=none,-Bstatic,-T,"$(cygpath -m "$S/firmware/sections.lds")",--strip-debug obj/start.o \
    $(ls obj/*.o | grep -v start.o) -lgcc 2>&1 | grep -v "RWX permissions" || true
${P}objcopy -O binary firmware/firmware.elf firmware/firmware.bin
python "$S/firmware/makehex.py" firmware/firmware.bin 32768 > firmware/firmware.hex

# 2. Compile and run the test bench (fazyrv/sim/tb) with this core variant.
printf '`define SIM\n`define CHUNKSIZE %s\n`define RFTYPE "%s"\n`define CONF "MIN"\n`define RVC "NONE"\n`define MEMDLY1 0\n' $CS $RF > defs.svh
$V/xvlog -sv defs.svh $CORE_RTL "$S/tb/wb_ram.sv" "$S/tb/tb.sv" > xvlog.log
$V/xelab tb -s tb_snap -timescale 1ns/1ps > xelab.log
$V/xsim tb_snap -R > xsim.log || true

ok=$(grep -c '\.\.OK' xsim.log || true)
if grep -q "DONE" xsim.log && [ "$ok" = "40" ]; then
  echo "riscv-tests CHUNKSIZE=$CS RFTYPE=$RF: 40/40 OK, $(grep -o 'finish called at time : [0-9]* ns' xsim.log | grep -o '[0-9]* ns')"
else
  echo "riscv-tests CHUNKSIZE=$CS RFTYPE=$RF: FAILED ($ok OK)"; exit 1
fi
