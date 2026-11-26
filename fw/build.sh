#!/usr/bin/env bash
# Build programs with the RISC-V GCC that ships with Vivado 2026.1.
#   fw/build.sh              -> fw/firmware.mem      workload (bench.c) for the FPGA and the power runs
#   fw/build.sh bench_sim    -> fw/firmware_sim.mem  same workload, LEDs change every pass (system test bench)
#   fw/build.sh counter      -> fw/firmware.mem      the old LED counter (main.c), ~0.77 s per step (4-bit)
#   fw/build.sh counter_sim  -> fw/firmware_sim.mem  LED counter with a short delay (sim/tb_top.sv)
#   fw/build.sh counter_pw / sleep_pw  -> firmware.mem   busy-wait / sleep LED counter, ~400k cycles per step
#   fw/build.sh sleep / sleep_sim      -> sleeping LED counter for the board / for sim (needs SLEEP=1 design)
set -e
cd "$(dirname "$0")"
export PATH="/c/AMDDesignTools/2026.1/gnu/riscv/nt/bin:$PATH"
P=riscv64-unknown-elf-
EXPECTED=$(python bench_ref.py)

case "${1:-bench}" in
  bench)       SRC=bench.c; OUT=firmware;     DEFS="-DEXPECTED=${EXPECTED}u -DLED_SHIFT=${LED_SHIFT:-7}" ;;
  bench_sim)   SRC=bench.c; OUT=firmware_sim; DEFS="-DEXPECTED=${EXPECTED}u -DLED_SHIFT=0" ;;
  counter)     SRC=main.c;  OUT=firmware;     DEFS="-DDELAY_SLOW=${DELAY:-3000000}u" ;;
  counter_sim) SRC=main.c;  OUT=firmware_sim; DEFS="-DDELAY_SLOW=200u" ;;
  counter_pw)  SRC=main.c;  OUT=firmware;     DEFS="-DDELAY_SLOW=12465u" ;;          # ~400k cycles per step (power runs)
  sleep)       SRC=sleep.c; OUT=firmware;     DEFS="-DSLEEP_CYCLES=96250000u" ;;     # board: ~0.77 s per step
  sleep_sim)   SRC=sleep.c; OUT=firmware_sim; DEFS="-DSLEEP_CYCLES=6400u" ;;         # like counter_sim (~6.5k cycles)
  sleep_pw)    SRC=sleep.c; OUT=firmware;     DEFS="-DSLEEP_CYCLES=400000u" ;;       # ~400k cycles per step (power runs)
  *) echo "unknown target $1"; exit 1 ;;
esac

${P}gcc -march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib -nostartfiles $DEFS \
    -Wl,-T,link.ld,--build-id=none,-Map,$OUT.map -o $OUT.elf start.S $SRC
${P}objcopy -O binary $OUT.elf $OUT.bin
${P}objdump -d $OUT.elf > $OUT.lst
# One 32-bit word per line, 1024 words (= 4 KB), for $readmemh.
python -c "
b = open('$OUT.bin','rb').read()
b += bytes((-len(b)) % 4)
w = [int.from_bytes(b[i:i+4],'little') for i in range(0,len(b),4)]
assert len(w) <= 1024, 'program larger than 4 KB'
w += [0]*(1024-len(w))
open('$OUT.mem','w').write(''.join('%08x\n' % x for x in w))
print('$OUT.mem: %d bytes ($SRC, ${1:-bench})' % len(b))
"
