"""Reference model of fw/bench.c: prints the expected result of one pass (hex)."""
M = 0xFFFFFFFF
N = 64


def xorshift32(x):
    x ^= (x << 13) & M
    x ^= x >> 17
    x ^= (x << 5) & M
    return x & M


def crc32(data):
    crc = 0xFFFFFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1) & M))
    return ~crc & M


seed = 0x12345678
buf = []
for _ in range(N):
    seed = xorshift32(seed)
    buf.append(seed)
crc = crc32(b"".join(w.to_bytes(4, "little") for w in buf))
buf.sort()
s = 0
for i, w in enumerate(buf):
    s = (s + (w ^ ((i << 24) & M))) & M
print(f"0x{(crc ^ s) & M:08x}")
