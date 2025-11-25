import numpy as np

from scipy.io import loadmat


mat_data = loadmat(r".\AL_0033pixel03041.mat")



num_items = len(mat_data)
print(f"The number of key-value pairs is: {num_items}")


# print keys and brief summaries
for key, val in mat_data.items():
    print(f"Key: {key!r}")
    print(f"  Type: {type(val)}")
    if isinstance(val, np.ndarray):
        print(f"  Shape: {val.shape}")
        flat = val.ravel()
        preview = flat[:10] if flat.size > 0 else flat
        print(f"  Preview (first up to 10 elements): {preview}")
    else:
        print(f"  Value (repr, trimmed): {repr(val)[:200]}")
    print()

