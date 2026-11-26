# Clock-gated sleep mode for a FazyRV RISC-V system on the PYNQ-Z2

EE6043 (Design of Digital ICs) project, University College Cork, 2026. Author: MD Kamrul Islam.

A complete RISC-V processor system, the FazyRV core with a 4 KB block RAM and a GPIO port, is taken
through the full AMD Vivado flow for the PYNQ-Z2 board (xc7z020clg400-1, 125 MHz). Its power is
estimated with the real switching activity of a program. The improvement is a sleep mode with clock
gating. A small sleep controller lets the program say how long it wants to wait, stops the processor's
clock with the FPGA's glitch-free clock buffer (BUFGCE) and starts it again at the right moment.

## Results

| | Baseline (busy-wait) | Sleep mode | Change |
|---|---|---|---|
| Average dynamic power, LED program | 11 mW | 2.0 mW | -82% |
| Time the processor clock runs | 100% | 0.11% | |
| Slack at the 8 ns board clock | +0.009 ns | +0.434 ns | met |
| Slice LUTs / flip-flops | 387 / 269 | 564 / 320 | +177 / +51 |
| Block RAM tiles | 1.5 | 1.5 | 0 |
| LED step on the board (SW0 off / on) | 0.77 s / 0.19 s | 0.775 s / 0.194 s | same |

The baseline with the workload program uses 12 mW of dynamic power with the real activity (the
default estimate without an activity file gives 18 mW). The sleep design ran on the board for a
191 s test in both speed modes without stopping.

## Folders

| Folder | What it holds |
|---|---|
| `fazyrv/` | The FazyRV core and reference SoC by M. Kissich and M. Baunach (git submodule, commit c325b91, MIT licence), used unchanged |
| `src/top_pynqz2.sv` | Board top level of the baseline: reset stretcher, switch synchroniser, pins |
| `src/sleep/` | The improvement: `sleep_ctrl.sv` (sleep controller), `top_pynqz2.sv` (BUFG + BUFGCE), `fsoc_sleep.sv` (copy of the reference SoC with the sleep controller on the bus) |
| `src/diag/` | Board-debug wrappers used to investigate the baseline's board problem (not part of the measured designs) |
| `constr/` | PYNQ-Z2 pin constraints |
| `fw/` | Programs: `bench.c` workload with Python reference model `bench_ref.py`, `main.c` busy-wait LED counter, `sleep.c` sleeping LED counter |
| `sim/` | Test benches: `tb_top.sv` (LED program), `tb_bench.sv` (workload), `tb_power.sv` (activity for the power analysis), `tb_long.sv` (long runs) |
| `scripts/` | Simulation, Vivado build, activity-based power and power-state model, board programming, screenshots |
| `results/` | Vivado reports, activity files and bitstreams of the four runs in the report |
| `report/` | Editable diagram sources, the power chart script and the frame-by-frame board video check |

Runs in `results/`:

| Run | Design | Program | Clock target |
|---|---|---|---|
| `base` | baseline | workload (`fw/bench.c`) | 8 ns |
| `busy_o_pw` | baseline | busy-wait LED counter, about 400,000 cycles per step | 8 ns |
| `sleep_o_pw` | sleep design | sleeping LED counter, about 400,000 cycles per step | 7.5 ns (meets 8 ns with +0.434 ns) |
| `sleep_o_board` | sleep design | sleeping LED counter, 96,250,000 cycles per step (0.77 s) | 7.5 ns |

The power runs use a shorter LED step (about 400,000 cycles) so that the simulation stays short, and
the functional test benches use about 6,500 cycles per step. The board build uses the real 0.77 s step.

## How to run

Needs AMD Vivado 2026.1 (it includes the RISC-V GCC used by `fw/build.sh`), Git Bash and Python 3.
The scripts expect Vivado in `C:/AMDDesignTools/2026.1`; change the paths at the top of the scripts
for another installation. Run only one Vivado build at a time.

```bash
git clone --recursive https://github.com/mdkamrulislam-web/ee6043-fazyrv-sleep-mode.git
cd ee6043-fazyrv-sleep-mode

bash fw/build.sh                         # workload -> fw/firmware.mem (goes into the bitstream)
bash scripts/sim_riscvtests.sh 4         # 40 RV32I instruction tests
bash scripts/sim_top.sh 4                # LED test bench (SLEEP=1 FW_SIM=sleep_sim for the sleep design)
bash scripts/sim_bench.sh 4              # workload test bench (SLEEP=1 for the sleep design)

vivado -mode batch -source scripts/build.tcl -tclargs base 4 8.0 \
       Flow_PerfOptimized_high Performance_ExplorePostRoutePhysOpt         # baseline
bash scripts/power_saif.sh base 3100     # activity-based power of the baseline (workload)
bash scripts/run_sleep_orig.sh           # busy-wait and sleep builds + power-state model

vivado -mode batch -source scripts/program.tcl -tclargs results/sleep_o_board/top_pynqz2_sleep_o_board.bit
```

The timing test builds in the report (Table 4) use the same build script, for example
`build.tcl -tclargs <run> 8 8.0` for the 8-bit core with default settings.

### Power of a gated clock

Vivado's power tool ignores switching activity on the enable of a global clock buffer. The script
`scripts/power_saif.tcl` therefore reports the sleep design twice with `set_case_analysis`, with the
clock forced on (awake) and forced off (asleep), reads the share of time awake from the activity file
and writes the average to `results/sleep_o_pw/power_states.txt`:

    P_average = f_awake * P_awake + (1 - f_awake) * P_asleep

## Reference

M. Kissich and M. Baunach, "FazyRV: Closing the Gap between 32-Bit and Bit-Serial RISC-V Cores with a
Scalable Implementation", Proc. 21st ACM International Conference on Computing Frontiers (CF '24),
pp. 240-248, 2024, doi:10.1145/3649153.3649195. Code: https://github.com/meiniKi/FazyRV
