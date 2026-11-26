"""Chart for the sleep-mode improvement: dynamic power of the busy-wait and the sleeping LED program.
Data: results/busy_o_pw/power_saif_summary.txt, results/sleep_o_pw/power_states.txt -> data/sleep_o_results.csv
    python report/make_sleep_charts.py
"""
import csv, re, sys
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

H = Path(__file__).resolve().parent
R = H.parent / "results"
kv = lambda p: dict(re.findall(r"(\w+)=([-\w.<]+)", p.read_text()))
BUSY, SLEEP, NAME = (sys.argv[1:4] + ["busy_o_pw", "sleep_o_pw", "chart_sleep_o"][len(sys.argv[1:4]):])
busy = float(kv(R / BUSY / "power_saif_summary.txt")["power_dynamic_w"]) * 1000
st = kv(R / SLEEP / "power_states.txt")
awake, asleep, avg, f = (float(st["dynamic_awake_w"]) * 1000, float(st["dynamic_asleep_w"]) * 1000,
                         float(st["dynamic_average_w"]) * 1000, float(st["f_awake"]))
with open(H / "data" / (NAME.replace("chart_", "") + "_results.csv"), "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["quantity", "value", "unit"])
    for k, v, u in [("busy-wait LED program, dynamic power", busy, "mW"), ("sleep design awake (clock on)", awake, "mW"),
                    ("sleep design asleep (clock off)", asleep, "mW"), ("fraction of time awake", f, ""),
                    ("sleep design average dynamic power", round(avg, 3), "mW")]:
        w.writerow([k, v, u])
plt.rcParams.update({"font.size": 12, "font.family": "Arial"})
fig, ax = plt.subplots(figsize=(7.5, 4.2), dpi=150)
labels = ["busy-wait\n(always running)", "sleep mode\nasleep (clock off)", "sleep mode\naverage"]
vals = [busy, asleep, avg]
bars = ax.bar(labels, vals, color=["#7f7f7f", "#9fd3b4", "#2e8b57"], width=0.55)
for b, v in zip(bars, vals):
    ax.text(b.get_x() + b.get_width() / 2, v, f"{v:.1f} mW", ha="center", va="bottom", fontsize=11)
ax.set_ylabel("Dynamic power (mW)")
ax.set_title(f"Same LED program behaviour; awake {f * 100:.2f}% of the time", fontsize=11, loc="left")
ax.spines[["top", "right"]].set_visible(False); ax.set_ylim(0, max(vals) * 1.25)
fig.tight_layout(); fig.savefig(H / "figures" / f"{NAME}.png"); plt.close(fig)
print("sleep chart done", busy, asleep, avg, f)
