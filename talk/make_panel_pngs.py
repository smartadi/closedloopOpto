"""Export the paper panels of Figures 2-5 as individual PNGs into talk/figureN/.

Not the assembled figures -- the individual panels, so they can be placed on slides one
at a time. PDFs are rasterised at 600 dpi and white-margin cropped; panels that only
exist as PNG are copied through.

Panel IDs come from PAPER.md's registry where there is one (Figs 2 and 3). Figure 4 has
no registry table -- its panels are named by the three-block story in PAPER.md
("Figure 4 — Controller state dependence"), so they are grouped by block here instead.
Retired panels (2D step response, 2H pre-var heatmap) are deliberately absent.

Figure 5's panels exist in two session variants; the 2026-07-21 set is the representative
session named in the PAPER.md caption, so that is the one exported. Its pooled panels
I/J/K are the sine_combined_* files (three sessions, same mouse and hemisphere).

Usage: python make_panel_pngs.py [figure2 figure3 ...]   (default: all)
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageChops

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
IMG = os.path.join(ROOT, "paper", "images")
BG = (255, 255, 255)
DPI = 600

FIG2 = [
    ("2A",   "figure2/imp_single_AL_0033_2025-01-29_en1.pdf"),
    ("2B",   "figure2/imp_response.pdf"),
    ("2C",   "figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf"),
    ("2Ci",  "figure2/tf_shape_across_sessions.pdf"),
    ("2E",   "figure2/onset_variance_slope.pdf"),
    ("2F",   "figure2/imp_motion_devscatter_all_sessions.pdf"),
    ("2G",   "figure2/imp_state_reldelta_scatter.pdf"),
    ("2I",   "figure2/ol_tf_trial_avg.pdf"),
    ("2J",   "figure2/imp_state_var_motion.pdf"),
    ("2K",   "figure2/imp_state_var_reldelta.pdf"),
    ("TFA",  "figure2/tf_tau_forest.pdf"),
    ("TFD",  "figure2/tf_model_swap.pdf"),
]
FIG3 = [
    ("3A", "figure3/panel_A.pdf"),
    ("3B", "figure3/panel_B.pdf"),
    ("3C", "figure3/panel_C.pdf"),
    ("3D", "figure3/panel_D.pdf"),
    ("3E", "figure3/panel_E.pdf"),
    ("3F", "figure3/all_variance_sessions.pdf"),
    ("3G", "figure3/all_average_sessions.pdf"),
    ("3H", "figure3/all_MSE_sessions.pdf"),
    ("3I", "figure3/variance_ratio_by_window.pdf"),
    ("3J", "figure3/MSE_ratio_by_window.pdf"),
    ("3K", "figure3/pooled_ol_cl_rmse_15sess.pdf"),
    ("3Iw", "figure3/variance_ratio_4windows.pdf"),
]
FIG4 = [
    # block 1 -- trial-average state dependence, OL steep vs CL flat
    ("b1_motion",        "figure4/factor_olcl_motion.pdf"),
    ("b1_initdev",       "figure4/factor_olcl_initdev.pdf"),
    ("b1_delta",         "figure4/factor_olcl_delta.pdf"),
    # block 2 -- error-contribution model + per-session factor slopes
    ("b2_decomp",        "figure4/f4p1_error_decomp.png"),
    ("b2_initdev_q",     "figure4/claim3_initdev_early_late.pdf"),
    ("b2_hi24_q",        "figure4/claim2_delta_hi24_late.pdf"),
    ("b2_lo12_q",        "figure4/claim2_delta_lo12_late.pdf"),
    ("b2_slope_motion",  "figure4/factor_slope_motion.pdf"),
    ("b2_slope_delta24", "figure4/factor_slope_delta24.pdf"),
    ("b2_slope_delta12", "figure4/factor_slope_delta12.pdf"),
    ("b2_slope_initdev", "figure4/factor_slope_initdev.pdf"),
    # block 3 -- residual / disturbance rejection (energy ratio)
    ("b3_demo_ol",       "figure4/f4_reject_demo_ol.png"),
    ("b3_demo_cl",       "figure4/f4_reject_demo_cl.png"),
    ("b3_paired",        "figure4/f4_reject_paired_er.png"),
    ("b3_gain",          "figure4/f4_reject_gain_er.png"),
    ("b3_capacity",      "figure4/f4_reject_capacity_er.png"),
    ("b3_trials",        "figure4/f4_reject_trials_er.png"),
    ("b3_stat",          "figure4/f4_reject_demo_stat_er.png"),
    # the contra -> ipsi coupling the Global signal is built from
    ("map_coupling",     "figure4/hemi_coupling_maps_sq.png"),
    ("map_kernel",       "figure4/hemi_kernel_primary.png"),
    ("map_rank",         "figure4/hemi_rank_curve.png"),
]
FIG5 = [
    # single representative session, AL_0048 2026-07-21 e1 (dark screen)
    ("5B", "figure5/sine_5B_single_trial_AL_0048_2026-07-21_1.pdf"),
    ("5C", "figure5/sine_5C_trialavg_AL_0048_2026-07-21_1.pdf"),
    ("5D", "figure5/sine_5D_trialavg_input_AL_0048_2026-07-21_1.pdf"),
    ("5E", "figure5/sine_5E_rmse_time_AL_0048_2026-07-21_1.pdf"),
    ("5F", "figure5/sine_5F_variance_AL_0048_2026-07-21_1.pdf"),
    ("5G", "figure5/sine_5G_rmse_violin_AL_0048_2026-07-21_1.pdf"),
    ("5H", "figure5/sine_5H_phase_lag_AL_0048_2026-07-21_1.pdf"),
    # pooled across the three sessions -- the performance claims in the caption
    ("5I", "figure5/sine_combined_rmse.pdf"),
    ("5J", "figure5/sine_combined_variance.pdf"),
    ("5K", "figure5/sine_combined_phase.pdf"),
    # pooled RMSE with the drowsy-trial exclusion shown alongside
    ("5Ix", "figure5/sine_rmse_pooled_all_with_clean.png"),
    ("5Ic", "figure5/sine_combined_rmse_clean_pooled.png"),
]


def trim(im):
    bb = ImageChops.difference(im, Image.new("RGB", im.size, BG)).getbbox()
    if not bb:
        return im
    return im.crop((max(0, bb[0] - 10), max(0, bb[1] - 10),
                    min(im.width, bb[2] + 10), min(im.height, bb[3] + 10)))


def export(group, panels):
    out = os.path.join(HERE, group)
    os.makedirs(out, exist_ok=True)
    made, missing = 0, []
    for pid, rel in panels:
        src = os.path.join(IMG, rel)
        if not os.path.exists(src):
            missing.append(rel)
            continue
        stem = os.path.splitext(os.path.basename(rel))[0]
        dst = os.path.join(out, f"{pid}_{stem}.png")
        if rel.endswith(".pdf"):
            base = dst[:-4]
            subprocess.run(["pdftoppm", "-png", "-r", str(DPI), "-singlefile", src, base],
                           check=True)
            im = trim(Image.open(dst).convert("RGB"))
            if max(im.size) > 5000:                   # a 600-dpi page is absurd on a slide
                k = 5000 / max(im.size)
                im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
            im.save(dst, dpi=(DPI, DPI))
        else:
            shutil.copyfile(src, dst)
            im = Image.open(dst)
        print(f"  {pid:16s} {im.size[0]}x{im.size[1]}  {os.path.basename(dst)}")
        made += 1
    print(f"[{group}] {made} panels -> {out}")
    for m in missing:
        print(f"  ! MISSING (skipped): {m}")
    return made


GROUPS = {"figure2": FIG2, "figure3": FIG3, "figure4": FIG4, "figure5": FIG5}
want = sys.argv[1:] or list(GROUPS)
for grp in want:
    print(f"\n=== {grp} ===")
    export(grp, GROUPS[grp])
