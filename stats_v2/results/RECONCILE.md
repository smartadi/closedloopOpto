# Reconciliation: clean-room rebuild vs old pipeline caches

## Tier 1: trial sets and per-trial full-window RMSE

| session | trials new | trials old | only new | only old | max abs RMSE diff | trials diff > 1e-6 |
|---|---|---|---|---|---|---|
| m1 | 120 | 120 | 0 | 0 | 1.78e-15 | 0 |
| m2 | 200 | 200 | 0 | 0 | 4.89e-07 | 0 |
| m3 | 200 | 200 | 0 | 0 | 8.88e-16 | 0 |
| m4 | 200 | 200 | 0 | 0 | 8.88e-16 | 0 |
| m5 | 60 | 60 | 0 | 0 | 8.88e-16 | 0 |
| m6 | 30 | 30 | 0 | 0 | 8.88e-16 | 0 |
| m7 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |
| m8 | 60 | 60 | 0 | 0 | 4.44e-16 | 0 |
| m9 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |
| m10 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |
| m11 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |
| m12 | 100 | 100 | 0 | 0 | 4.44e-16 | 0 |
| m13 | 100 | 100 | 0 | 0 | 1.33e-15 | 0 |
| m14 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |
| m15 | 100 | 100 | 0 | 0 | 8.88e-16 | 0 |

## Tier 2: per-session Fig 3 ratios (new / old)

| metric | window | max abs diff | worst session | new | old |
|---|---|---|---|---|---|
| rmse | pre | 8.33e-08 | m2 | 0.9862 | 0.9862 |
| rmse | early | 6.77e-03 | m5 | 0.8916 | 0.8848 |
| rmse | late | 3.91e-03 | m7 | 0.7282 | 0.7243 |
| rmse | full | 8.88e-09 | m2 | 0.8877 | 0.8877 |
| rmse | post | 3.20e-08 | m2 | 1.0389 | 1.0389 |
| var | pre | 2.73e-07 | m14 | 0.7767 | 0.7767 |
| var | early | 2.76e-02 | m8 | 1.4832 | 1.4556 |
| var | late | 6.02e-03 | m7 | 0.6459 | 0.6399 |
| var | full | 3.60e-07 | m3 | 0.5940 | 0.5940 |
| var | post | 5.82e-07 | m13 | 1.2265 | 1.2265 |
