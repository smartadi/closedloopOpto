"""(brain_paper utils, 2026-10-10; feeds loadData.m's local motion fallback.) Extract the motion traces from a facemap face_proc.npy into plain .npy arrays MATLAB can read
with readNPY: <prefix>_motion_<i>.npy (float64, one per ROI index) and <prefix>_motSVD_0.npy.
Usage: python -I faceproc_convert.py <src face_proc.npy> <dst prefix> [--inspect]"""
import sys
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
proc = np.load(src, allow_pickle=True).item()
if '--inspect' in sys.argv:
    for k, v in proc.items():
        if isinstance(v, list):
            print(k, 'list', len(v), [getattr(x, 'shape', type(x).__name__) for x in v][:6])
        else:
            print(k, type(v).__name__, getattr(v, 'shape', ''))
    sys.exit(0)
for i, m in enumerate(proc.get('motion', [])):
    a = np.asarray(m)
    if a.size:
        np.save('%s_motion_%d.npy' % (dst, i), a.astype(np.float64).ravel())
        print('motion_%d' % i, a.shape)
s0 = proc.get('motSVD', [None])[0]
if s0 is not None and np.asarray(s0).size:
    np.save('%s_motSVD_0.npy' % dst, np.asarray(s0, dtype=np.float64))
    print('motSVD_0', np.asarray(s0).shape)
