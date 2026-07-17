"""
draw_mask.py — hand-draw the brain (cortical-window) mask for a session, if the
automatic mask in make_video.py isn't clean enough.

Opens the session mean image; click to place polygon vertices around the cortex,
then press ENTER to save. Saves assets/mask_<session>.npy — make_video.py picks it
up automatically (delete the file to revert to the auto mask).

Run (needs a GUI backend — run in a normal desktop session, not headless):
  .venv/Scripts/python.exe presentation/draw_mask.py --session m5
  .venv/Scripts/python.exe presentation/draw_mask.py --session m13

Controls:
  • left-click        add a vertex
  • drag a vertex     adjust it
  • ESC               clear and start over
  • ENTER             rasterize + save the mask, then close
"""
import argparse
import os
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import PolygonSelector
from matplotlib.path import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", default="m5")
    args = ap.parse_args()

    D = np.load(os.path.join(ASSETS, f"demo_data_{args.session}.npz"), allow_pickle=True)
    mimg = D["mimg"]; roi = D["roi"]; n = mimg.shape[0]
    out = os.path.join(ASSETS, f"mask_{args.session}.npy")

    fig, ax = plt.subplots(figsize=(8, 8))
    ax.imshow(mimg, cmap="gray", vmin=np.percentile(mimg, 2), vmax=np.percentile(mimg, 98),
              interpolation="bilinear")
    ax.plot(roi[0], roi[1], "s", mec="#e11fbf", mfc="none", ms=12, mew=2)
    ax.set_title(f"{args.session}: click a polygon around the cortex, then press ENTER "
                 f"(ESC = restart)", fontsize=11)
    ax.set_xlim(0, n); ax.set_ylim(n, 0)

    state = {"verts": []}

    def onselect(verts):
        state["verts"] = list(verts)

    selector = PolygonSelector(ax, onselect, useblit=True,
                               props=dict(color="#1a9e5f", linewidth=2, alpha=0.9))

    def on_key(event):
        if event.key == "enter":
            verts = state["verts"] or list(selector.verts)
            if len(verts) < 3:
                print("need at least 3 vertices before ENTER"); return
            yy, xx = np.mgrid[0:n, 0:n]
            pts = np.column_stack([xx.ravel(), yy.ravel()])
            mask = Path(verts).contains_points(pts).reshape(n, n)
            np.save(out, mask)
            print(f"saved {out}  ({int(mask.sum())} px, ROI inside = "
                  f"{bool(mask[int(roi[1]), int(roi[0])])})")
            plt.close(fig)

    fig.canvas.mpl_connect("key_press_event", on_key)
    print("draw the polygon, then press ENTER to save (ESC to restart)")
    plt.show()


if __name__ == "__main__":
    main()
