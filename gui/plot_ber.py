# BER/FER waterfall plot for QC-LDPC irregular decoder
# Moustafa Salman
# Run from project root: python gui/plot_ber.py

import sys, math
from pathlib import Path
import numpy as np

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
except ImportError:
    sys.exit("pip install matplotlib")

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# 13-point Monte Carlo results, stopping at 100 FE or 1e5 frames per point
SNR = [1.00,1.25,1.50,1.75,2.00,2.25,2.50,2.75,3.00,3.25,3.50,3.75,4.00]
BER = [5.804e-02,3.922e-02,2.042e-02,1.017e-02,3.722e-03,1.430e-03,
       3.056e-04,8.267e-05,2.033e-05,7.539e-06,3.496e-06,7.422e-07,5.859e-07]
FER = [0.7634,0.5208,0.3289,0.1887,0.0702,0.0310,0.0078,0.0022,
       0.0007,0.0003,0.0002,None,None]  # None = no frame errors in 1e5 trials


def bpsk_ber(ebn0_db):
    # Theoretical uncoded BPSK: BER = 0.5 * erfc(sqrt(Eb/N0))
    lin = 10 ** (np.asarray(ebn0_db) / 10.0)
    return np.array([0.5 * math.erfc(math.sqrt(e)) for e in lin])


snr_theory = np.linspace(0.5, 4.5, 300)
ber_theory = bpsk_ber(snr_theory)

plt.rcParams.update({
    "figure.facecolor": "white",
    "axes.facecolor":   "white",
    "axes.edgecolor":   "#333333",
    "axes.linewidth":   1.0,
    "grid.color":       "#cccccc",
    "grid.linewidth":   0.6,
    "font.family":      "serif",
    "font.size":        10,
    "axes.labelsize":   11,
    "legend.fontsize":  9,
    "xtick.labelsize":  9,
    "ytick.labelsize":  9,
})

fig, ax = plt.subplots(figsize=(5.5, 4.0))

ax.semilogy(snr_theory, ber_theory,
            color="black", linewidth=1.2, linestyle="--",
            label="Uncoded BPSK (theoretical)")

ax.semilogy(SNR, BER,
            color="#1a56a0", linewidth=1.8,
            marker="o", markersize=4, markerfacecolor="white",
            markeredgewidth=1.4,
            label=r"QC-LDPC $(2/3,5/6)$-irr., $n=512$, rate $1/2$")

# FER plotted as dotted line with square markers
fer_snr = [s for s, f in zip(SNR, FER) if f is not None]
fer_val = [f for f in FER if f is not None]
ax.semilogy(fer_snr, fer_val,
            color="#1a56a0", linewidth=1.2,
            linestyle=":", marker="s", markersize=3.5,
            markerfacecolor="#1a56a0",
            label="FER (same code)")

# Annotate points where no frame errors were observed
for s, f in zip(SNR, FER):
    if f is None:
        ax.annotate("0 obs.", xy=(s, 4e-7),
                    fontsize=7, color="#666666",
                    ha="center", va="bottom", rotation=90)

# Mark the waterfall threshold at 2.5 dB
ax.axvline(2.5, color="#aaaaaa", linewidth=0.8, linestyle=":")
ax.text(2.52, 2e-1, "FER$\\approx10^{-2}$\n@ 2.5 dB",
        fontsize=7.5, color="#666666", va="top")

ax.set_xlabel(r"$E_b/N_0$ (dB)")
ax.set_ylabel("BER / FER")
ax.set_xlim(0.5, 4.5)
ax.set_ylim(1e-7, 1.5)
ax.yaxis.set_major_formatter(ticker.LogFormatterMathtext())
ax.grid(True, which="both")
ax.grid(True, which="minor", linewidth=0.3)
ax.legend(loc="lower left", framealpha=0.9)

fig.tight_layout(pad=0.5)

out_dir = PROJECT_ROOT / "results"
out_dir.mkdir(exist_ok=True)

fig.savefig(out_dir / "ber_fer_waterfall.pdf", dpi=200, bbox_inches="tight")
fig.savefig(out_dir / "ber_fer_waterfall.png", dpi=200, bbox_inches="tight")
print(f"Saved to {out_dir / 'ber_fer_waterfall.pdf'}")
print(f"Saved to {out_dir / 'ber_fer_waterfall.png'}")
