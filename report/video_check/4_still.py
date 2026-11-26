import sys  # needs: pip install av numpy pillow
import av
from PIL import Image
c = av.open(sys.argv[1]); s = c.streams.video[0]; s.thread_type = "AUTO"
t = float(sys.argv[3]); c.seek(int(t / s.time_base), stream=s, backward=True)
for f in c.decode(s):
    if f.time >= t: im = f.to_image(); break
im = im.crop((1150, 430, 6100, 3780)).rotate(180).resize((2400, 1624))
im.save(sys.argv[2]); print(im.size)
