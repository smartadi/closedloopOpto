"""Onset check figures: example trials per session with the old and corrected onsets marked.

Per session (one row): two OL and two CL single trials, then the OL trial average.
  column 1: OL trial with the largest onset correction (or the worst laser-rise offset if the
            session was not corrected); column 2: a random OL trial;
  column 3: CL trial with the largest correction (or worst rise); column 4: a random CL trial;
  column 5: OL average aligned on the corrected onset vs on the old (stimStarts) onset.
Each panel: laser command (top strip, V) above the controlled site's dF/F (bottom, %).
x = frames from the corrected onset. Lines: corrected onset (black solid), old stimStarts onset
(orange dashed), detected laser rise (aqua dotted). The rise should sit ~L frames after the
corrected onset (L = 1.88 old builds, 2.86 new builds; bookkeeping + 24 ms latency).

Run after onsets.py:  stats_v2/.venv/Scripts/python.exe -I stats_v2/plot_onsets.py
Writes data/stats_v2/onset_check_1.png .. _3.png (5 sessions each).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2"
X0, X1 = -12, 30            # frames around the corrected onset
INK, MUTED = "#0b0b0b", "#52514e"
C_DFK, C_OLD, C_RISE = "#2a78d6", "#eb6834", "#1baf7a"
L = {"old": 1.88, "new": 2.86}
M14_SHIFT = 11
rng = np.random.default_rng(7)


def pick(df, cond, corrected):
    d = df[df.condition == cond]
    key = d["shift"].abs() if corrected else (d["rise_offset"] - L_cur).abs()
    worst = d.loc[key.fillna(-1).idxmax()]
    rest = d.drop(index=worst.name)
    return [worst, rest.iloc[int(rng.integers(len(rest)))]]


def draw_trial(ax_c, ax_f, s, on_new, on_old, rise_rel, title):
    tb, dt = s["timeBlue"], s["dt_frame"]
    t0 = tb[on_new]
    a, b = np.searchsorted(s["inpTime"], [t0 + X0 * dt, t0 + X1 * dt])
    ax_c.plot((s["inpTime"][a:b] - t0) / dt, s["cmd"][a:b], color=MUTED, lw=1)
    k = np.arange(on_new + X0, on_new + X1 + 1)
    ax_f.plot(k - on_new, s["dFk"][k], color=C_DFK, lw=1.4, marker="o", ms=2.2)
    for ax in (ax_c, ax_f):
        ax.axvline(0, color=INK, lw=1.2)
        ax.axvline(on_old - on_new, color=C_OLD, lw=1.2, ls="--")
        if np.isfinite(rise_rel):
            ax.axvline(rise_rel, color=C_RISE, lw=1.4, ls=":")
    ax_c.set_title(title, fontsize=7.5, loc="left", color=INK)


def style(ax_c, ax_f, first_col, last_row):
    for ax in (ax_c, ax_f):
        ax.set_xlim(X0, X1)
        ax.tick_params(labelsize=6.5, colors=MUTED, length=2)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        ax.spines["left"].set_color("#c9c8c3")
        ax.spines["bottom"].set_color("#c9c8c3")
        ax.grid(axis="x", color="#ecebe7", lw=0.6)
    ax_c.tick_params(labelbottom=False)
    if first_col:
        ax_c.set_ylabel("cmd (V)", fontsize=6.5, color=MUTED)
        ax_f.set_ylabel("ΔF/F (%)", fontsize=6.5, color=MUTED)
    if last_row:
        ax_f.set_xlabel("frames from corrected onset", fontsize=6.5, color=MUTED)


def main():
    global L_cur
    oc = pd.read_csv(OUT / "onsets_corrected.csv")
    ids = loader.SESSION_IDS
    for fig_i, chunk in enumerate([ids[0:5], ids[5:10], ids[10:15]], start=1):
        fig = plt.figure(figsize=(17, 2.15 * len(chunk) + 0.9), dpi=130)
        fig.patch.set_facecolor("#fcfcfb")
        outer = fig.add_gridspec(len(chunk), 5, hspace=0.62, wspace=0.28,
                                 left=0.085, right=0.99, top=1 - 0.75 / fig.get_figheight(),
                                 bottom=0.45 / fig.get_figheight())
        for r, sid in enumerate(chunk):
            s = loader.load_session(sid, dfk_offset=M14_SHIFT if sid == "m14" else 0)
            L_cur = L[s["build"]]
            d = oc[oc.session == sid].reset_index(drop=True)
            corrected = bool((d["shift"] != 0).any())
            on_new = d["onset_frame"].to_numpy() - 1
            on_old = d["onset_frame_stim"].to_numpy() - 1
            # rise relative to the corrected onset = rise offset vs the old onset - shift
            rise_rel = d["rise_offset"].to_numpy() - d["shift"].to_numpy()
            ex = pick(d, "OL", corrected) + pick(d, "CL", corrected)
            for c, row in enumerate(ex):
                j = int(row.name)
                g = outer[r, c].subgridspec(2, 1, height_ratios=[1, 2.2], hspace=0.08)
                ax_c, ax_f = fig.add_subplot(g[0]), fig.add_subplot(g[1], sharex=None)
                tag = "largest shift" if corrected else "worst rise"
                tag = tag if c in (0, 2) else "random"
                title = (f"{row.condition} · trial {int(row.trial_index)} · {tag} · "
                         f"shift {int(row['shift']):+d} · rise {rise_rel[j]:+.1f}")
                draw_trial(ax_c, ax_f, s, on_new[j], on_old[j], rise_rel[j], title)
                style(ax_c, ax_f, c == 0, r == len(chunk) - 1)
            # column 5: OL average, aligned on the corrected vs the old onset
            g = outer[r, 4].subgridspec(2, 1, height_ratios=[1, 2.2], hspace=0.08)
            ax_c, ax_f = fig.add_subplot(g[0]), fig.add_subplot(g[1])
            ol = np.flatnonzero(d.condition.to_numpy() == "OL")
            k = np.arange(X0, X1 + 1)
            avg_new = np.nanmean([s["dFk"][on_new[i] + k] for i in ol], axis=0)
            avg_old = np.nanmean([s["dFk"][on_old[i] + k] for i in ol], axis=0)
            base = lambda v: v - np.nanmean(v[: -X0])  # noqa: E731
            ax_f.plot(k, base(avg_old), color=C_OLD, lw=1.4, ls="--")
            ax_f.plot(k, base(avg_new), color=C_DFK, lw=1.6)
            tb, dt = s["timeBlue"], s["dt_frame"]
            grid = np.linspace(X0, X1, 400)
            cm = np.mean([np.interp(tb[on_new[i]] + grid * dt, s["inpTime"], s["cmd"]) for i in ol],
                         axis=0)
            ax_c.plot(grid, cm, color=MUTED, lw=1)
            for ax in (ax_c, ax_f):
                ax.axvline(0, color=INK, lw=1.2)
                ax.axvline(L_cur, color=C_RISE, lw=1.4, ls=":")
            ax_c.set_title(f"OL average, n = {len(ol)} (blue new, orange old)",
                           fontsize=7.5, loc="left", color=INK)
            style(ax_c, ax_f, False, r == len(chunk) - 1)
            fig.text(0.005, 1 - (r + 0.5) / len(chunk) * (1 - 1.2 / fig.get_figheight())
                     - 0.75 / fig.get_figheight(),
                     f"{sid}\n{s['mouse']}\n{s['date'][5:]}\n{'corrected' if corrected else 'unchanged'}"
                     + ("\ndFk +11" if sid == "m14" else ""),
                     fontsize=7, color=INK, va="center", ha="left", weight="bold")
            del s
        fig.text(0.085, 1 - 0.3 / fig.get_figheight(),
                 "Black solid = corrected onset   ·   orange dashed = old stimStarts onset   ·   "
                 "aqua dotted = laser command rise (single trials) / expected rise at L (average)   ·   "
                 "top strip = laser command (V), bottom = ΔF/F (%)",
                 fontsize=8.5, color=INK)
        p = OUT / f"onset_check_{fig_i}.png"
        fig.savefig(p, facecolor=fig.get_facecolor())
        plt.close(fig)
        print("wrote", p)


if __name__ == "__main__":
    main()
