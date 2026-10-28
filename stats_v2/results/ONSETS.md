# Corrected onsets (OL laser-command rise)

Reference offset L (frames, logged onset frame -> first laser command; NOT loop latency, see docstring): old builds 1.88, new builds 2.86.
A session is corrected if > 0% of its OL trials sit > 1.5 frames from L.
cl_check = CL trials whose own rise was detected: share within 1 frame of the OL-derived estimate.

```
session   mouse build    L  ol_offset_median  ol_offset_min  ol_offset_max  ol_off_frac  corrected  shift_median  shift_min  shift_max  cl_check_n  cl_check_within1  n_resync
     m1 AL_0033   old 1.88              5.65           4.65           6.67         1.00       True           4.0          3          5          64              0.97         0
     m2 AL_0033   old 1.88              6.28           5.53           6.82         1.00       True           4.0          4          5         103              0.98         0
     m3 AL_0033   old 1.88              1.44          -2.91           3.58         0.36       True           0.0         -5          2          99              0.95         0
     m4 AL_0033   old 1.88              1.36          -4.95           3.39         0.34       True           0.0         -7          2         108              0.99         0
     m5 AL_0033   old 1.88              1.98          -0.96           3.49         0.25       True           0.0         -3          2          24              1.00         0
     m6 AL_0033   old 1.88              2.05           0.26           2.60         0.07       True           0.0         -2          1          16              1.00         0
     m7 AL_0033   old 1.88              2.06          -0.98           3.00         0.09       True           0.0         -3          1          54              0.94         0
     m8 AL_0033   old 1.88              2.18          -0.77           4.14         0.18       True           0.0         -3          2          22              1.00         0
     m9 AL_0039   old 1.88              1.89           1.86           2.89         0.00      False           0.0          0          0          50              0.96         0
    m10 AL_0039   old 1.88              1.89           1.84           2.89         0.00      False           0.0          0          0          52              0.98         0
    m11 AL_0039   old 1.88              1.86           1.86           2.88         0.00      False           0.0          0          0          50              0.98         0
    m12 AL_0033   old 1.88              1.89           1.86           2.02         0.00      False           0.0          0          0          65              1.00         0
    m13 AL_0039   old 1.88              1.89           1.86           2.96         0.00      False           0.0          0          0          45              0.89         0
    m14 AL_0048   new 2.86              2.86           1.86           4.23         0.00      False           0.0          0          0          55              0.85         0
    m15 AL_0051   new 2.86              2.86           2.26           3.88         0.00      False           0.0          0          0          45              0.96         0
```
