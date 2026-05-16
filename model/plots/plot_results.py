import numpy as np
import matplotlib.pyplot as plt

# =========================
# LOAD RESULTS
# =========================

snr = np.load("results/snr.npy")
ber = np.load("results/ber.npy")
fer = np.load("results/fer.npy")

print("SNR:", snr)
print("BER:", ber)
print("FER:", fer)

# =========================
# FIX LOG-PLOT ZEROS
# =========================

ber_plot = np.copy(ber)
fer_plot = np.copy(fer)

ber_plot[ber_plot == 0] = 1e-10
fer_plot[fer_plot == 0] = 1e-10

# =========================
# BER PLOT
# =========================

plt.figure(figsize=(8, 6))

plt.semilogy(
    snr,
    ber_plot,
    marker='o',
    linewidth=2,
    markersize=8
)

plt.xlabel("Eb/N0 (dB)", fontsize=14)
plt.ylabel("Bit Error Rate (BER)", fontsize=14)

plt.title("LDPC BER Performance", fontsize=16)

plt.grid(True, which='both', linestyle='--')

plt.tight_layout()

plt.savefig(
    "results/ber.png",
    dpi=300,
    bbox_inches='tight'
)

# =========================
# FER PLOT
# =========================

plt.figure(figsize=(8, 6))

plt.semilogy(
    snr,
    fer_plot,
    marker='s',
    linewidth=2,
    markersize=8
)

plt.xlabel("Eb/N0 (dB)", fontsize=14)
plt.ylabel("Frame Error Rate (FER)", fontsize=14)

plt.title("LDPC FER Performance", fontsize=16)

plt.grid(True, which='both', linestyle='--')

plt.tight_layout()

plt.savefig(
    "results/fer.png",
    dpi=300,
    bbox_inches='tight'
)

# =========================
# SHOW PLOTS
# =========================

print("Plots generated successfully.")

plt.show()
