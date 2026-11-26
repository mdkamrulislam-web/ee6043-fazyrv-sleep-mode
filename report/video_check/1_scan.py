import sys, time, pickle  # needs: pip install av numpy pillow
import av, numpy as np
c = av.open(sys.argv[1]); s = c.streams.video[0]; s.thread_type = "AUTO"
res = []; t0 = time.time()
for i, f in enumerate(c.decode(s)):
    a = f.reformat(width=960, height=540, format="rgb24").to_ndarray().astype(np.int16)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    m = (G >= 225) & (G >= R)          # bright green / white-hot LED cores
    ys, xs = np.nonzero(m)
    res.append((f.time, xs.astype(np.int16), ys.astype(np.int16)))
    if i % 500 == 0: print(i, f.time, round(time.time() - t0), flush=True)
pickle.dump(res, open(sys.argv[2], "wb"))
print("done", len(res), round(time.time() - t0))
