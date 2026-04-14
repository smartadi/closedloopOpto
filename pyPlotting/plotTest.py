import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat


mat_data = loadmat(r".\AL_0033pixel03041.mat")

# Extract dFk data
dFk = mat_data['dFk'].ravel()

# Plot dFk
plt.figure(figsize=(12, 6))
plt.plot(dFk)
plt.xlabel('Sample Index')
plt.ylabel('dFk')
plt.title('dFk Signal')
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.show()

