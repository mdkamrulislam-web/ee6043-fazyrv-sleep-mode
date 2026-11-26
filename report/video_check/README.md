# Board video check (sleep design, results/sleep_o_board)

Video: phone, 8K HEVC, 30 fps, 191 s, 5,728 frames, recorded 21 Nov 2026 00:13
(not in the repo: 1.9 GB). Board filmed upside down (LD0 is the leftmost LED in the raw frame).
SW0 off for about 0-95 s, switched on at about 95-97 s, on until the end.

    python -I 1_scan.py <video.mp4> scan.pkl        # bright green pixels per frame (about 7 min)
    python -I 2_clusters.py scan.pkl rows.pkl       # LED blobs per frame
    python -I 3_decode.py rows.pkl                  # binary value per frame, steps, all-off moments
    python -I 4_still.py <video.mp4> fig.png 100.2  # board frame for the report (rotated upright)

The scripts need Python 3 with PyAV, numpy and Pillow (pip install av numpy pillow).

Result (results_sleep_o_board.txt):
- SW0 off: all LEDs off every 12.40 s; 110 clean steps, 0.733-0.800 s, mean 0.775 s (programmed 0.770 s).
- SW0 on: all LEDs off every 3.10 s; 475 clean steps, 0.167-0.233 s, mean 0.194 s (programmed 0.1925 s).
- Ratio 4.00. 616 LED states; every step +1, except 18 misreads, all inside three moments
  when the camera moved (0-5.6 s, 35.4-36.4 s) or the hand was on SW0 (94.3-98.7 s).
- No stop in 191 s.
