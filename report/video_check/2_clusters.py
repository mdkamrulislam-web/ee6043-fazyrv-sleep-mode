import sys, pickle  # needs: pip install av numpy pillow
import numpy as np
res = pickle.load(open(sys.argv[1], "rb"))
def clusters(xs, ys, gap=6):
    if len(xs) == 0: return []
    o = np.argsort(xs); xs, ys = xs[o], ys[o]
    out, st = [], 0
    for i in range(1, len(xs) + 1):
        if i == len(xs) or xs[i] - xs[i-1] > gap:
            out.append((float(xs[st:i].mean()), float(ys[st:i].mean()), i - st)); st = i
    return out
rows = []
for t, xs, ys in res:
    xs = xs.astype(int); ys = ys.astype(int)
    d = (xs > 430) & (xs < 600) & (ys > 300) & (ys < 440)
    dn = clusters(xs[d], ys[d]); dn = max(dn, key=lambda c: c[2]) if dn else None
    b = (xs > 150) & (xs < 420) & (ys > 80) & (ys < 180)
    lc = [c for c in clusters(xs[b], ys[b]) if c[2] >= 3]
    rows.append((t, dn, lc))
pickle.dump(rows, open(sys.argv[2], "wb"))
nod = sum(1 for r in rows if r[1] is None); print("frames", len(rows), "no DONE", nod)
dx = [c[0] - r[1][0] for r in rows if r[1] for c in r[2]]
h, e = np.histogram(dx, bins=range(-360, -100, 5)); 
for hh, ee in zip(h, e): 
    if hh: print(ee, hh)
