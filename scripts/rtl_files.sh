# Sourced by the sim scripts: sets CORE_RTL to the FazyRV RTL files.
CORE_RTL=""
for f in "$ROOT"/fazyrv/rtl/*.sv "$ROOT"/fazyrv/rtl/*.v; do
  CORE_RTL="$CORE_RTL $f"
done

# SLEEP=1 -> sleep design: gated-clock top level + fsoc_sleep + sleep_ctrl (src/sleep/)
if [ "${SLEEP:-0}" = "1" ]; then
  TOP_RTL="$ROOT/src/sleep/top_pynqz2.sv $ROOT/src/sleep/fsoc_sleep.sv $ROOT/src/sleep/sleep_ctrl.sv"
  echo "top: SLEEP design (clock gating)"
else
  TOP_RTL="$ROOT/src/top_pynqz2.sv"
fi
GLBL=/c/AMDDesignTools/2026.1/Vivado/data/verilog/src/glbl.v
