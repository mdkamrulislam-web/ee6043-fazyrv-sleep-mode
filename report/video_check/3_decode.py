import sys, pickle
rows = pickle.load(open(sys.argv[1], "rb"))
sig = lambda lc: [c for c in lc if c[2] >= 15]
fr = [(t, sig(lc)) for t, dn, lc in rows]
full = [(t, [c[0] for c in s]) for t, s in fr if len(s) == 4]
def slots(t):
    return min(full, key=lambda f: abs(f[0] - t))[1]
# stable states: runs of identical decoded value lasting >= 3 frames
vals = []
for t, s in fr:
    sl = slots(t); v = 0
    for c in s:
        k = min(range(4), key=lambda i: abs(sl[i] - c[0])); v |= 1 << k
    vals.append((t, v))
states = []; i = 0
while i < len(vals):
    j = i
    while j < len(vals) and vals[j][1] == vals[i][1]: j += 1
    if j - i >= 3: states.append([vals[i][0], vals[j-1][0], vals[i][1]])
    i = j
# merge consecutive equal states split by glitches
m = []
for s in states:
    if m and m[-1][2] == s[2]: m[-1][1] = s[1]
    else: m.append(s)
bad = 0
for a, b in zip(m, m[1:]):
    if b[2] != (a[2] + 1) % 16: bad += 1; print("jump", round(a[0],2), a[2], "->", round(b[0],2), b[2])
print("states", len(m), "bad", bad, "first", m[0], "last", m[-1])
d = [(round(b[0]-a[0],3), round(a[0],2)) for a, b in zip(m, m[1:])]
slow = [x for x, t in d if t < 90]; fast = [x for x, t in d if t > 99]
print("slow steps", len(slow), min(slow), max(slow), sum(slow)/len(slow))
print("fast steps", len(fast), min(fast), max(fast), sum(fast)/len(fast))
print([x for x in d if 88 < x[1] < 100])
print("longest step", max(d))
win = [(0, 5.6), (35.4, 36.4), (94.3, 98.7)]
inw = lambda t: any(a <= t <= b for a, b in win)
cl = [(x, t) for x, t in d if not inw(t) and not inw(t + x)]
s2 = [x for x, t in cl if t < 94]; f2 = [x for x, t in cl if t > 98]
print("clean slow", len(s2), min(s2), max(s2), round(sum(s2)/len(s2), 4))
print("clean fast", len(f2), min(f2), max(f2), round(sum(f2)/len(f2), 4))
