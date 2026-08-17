"""
plot_qkd_results.py — BB84 Key Rate vs QBER
Plots both CCSDS and QC-LDPC results on the same figure.
Place in: LDPC-FPGA-Decoder/model/plots/plot_qkd_results.py
Run from project root: python -m model.plots.plot_qkd_results
"""

import sys, math
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

# ── Results ───────────────────────────────────────────────────────────────────
QBER = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10]

# CCSDS simulation results
CCSDS_KR  = [0.423, 0.362, 0.290, 0.277, 0.204, 0.168, 0.138, 0.123, 0.071, 0.010]
CCSDS_FER = [0.000, 0.000, 0.000, 0.000, 0.000, 0.080, 0.280, 0.540, 0.760, 0.960]

# QC-LDPC simulation results
QC_KR  = [0.4192, 0.3586, 0.3056, 0.2577, 0.2136, 0.1726, 0.1341, 0.0978, 0.0635, 0.0103]
QC_FER = [0.000,  0.000,  0.000,  0.000,  0.000,  0.040,  0.260,  0.660,  0.760,  0.900]

# ── Theoretical curves ────────────────────────────────────────────────────────
def h(p):
    p = np.clip(p, 1e-10, 1 - 1e-10)
    return float(-p * math.log2(p) - (1-p) * math.log2(1-p))

qber_th = np.linspace(0.001, 0.14, 300)
shannon     = np.array([max(0, 1 - 2*h(q)) for q in qber_th])
theoretical = np.array([max(0, 0.5 - h(q))  for q in qber_th])

# ── Figure ────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))

for ax, kr, fer, label, colour in [
    (axes[0], CCSDS_KR, CCSDS_FER,
     'CCSDS rate-0.5 LDPC', '#1a56a0'),
    (axes[1], QC_KR,    QC_FER,
     'QC-LDPC irregular rate-0.5', '#1a8050'),
]:
    ax.plot(qber_th, shannon,
            'k--', linewidth=1.5, label='Shannon limit (f=1.0)')
    ax.plot(qber_th, theoretical,
            color=colour, linewidth=2.0,
            label=f'{label} (theoretical)')
    ax.plot(QBER, kr,
            'o', color='#cc2222', markersize=7, zorder=5)
    ax.plot(QBER, kr,
            '--', color='#e08080', linewidth=1.2, alpha=0.7,
            label='Simulated (LDPC reconciliation)')
    ax.axvline(0.11, color='gray', linewidth=1.0, linestyle=':',
               label='BB84 security limit (11%)')
    ax.set_xlabel('QBER', fontsize=11)
    ax.set_ylabel('Secure Key Rate (bits/sifted bit)', fontsize=11)
    ax.set_xlim(0, 0.15)
    ax.set_ylim(-0.02, 1.02)
    ax.legend(fontsize=9, loc='upper right')
    ax.grid(True, alpha=0.4)

axes[0].set_title('BB84 Secure Key Rate vs QBER\nCCSDS LDPC Reconciliation',
                  fontsize=11)
axes[1].set_title('BB84 Secure Key Rate vs QBER\nQC-LDPC Irregular Reconciliation',
                  fontsize=11)

fig.tight_layout(pad=1.5)

out_dir = PROJECT_ROOT / 'results'
out_dir.mkdir(exist_ok=True)

# Save individual figures too
fig_c, ax_c = plt.subplots(figsize=(7, 5))
ax_c.plot(qber_th, shannon, 'k--', linewidth=1.5, label='Shannon limit (f=1.0)')
ax_c.plot(qber_th, theoretical, color='#1a56a0', linewidth=2.0,
          label='CCSDS rate-0.5 LDPC (theoretical)')
ax_c.plot(QBER, CCSDS_KR, 'o', color='#cc2222', markersize=7, zorder=5)
ax_c.plot(QBER, CCSDS_KR, '--', color='#e08080', linewidth=1.2, alpha=0.7,
          label='Simulated (LDPC reconciliation)')
ax_c.axvline(0.11, color='gray', linewidth=1.0, linestyle=':',
             label='BB84 security limit (11%)')
ax_c.set_xlabel('QBER', fontsize=12)
ax_c.set_ylabel('Secure Key Rate (bits/sifted bit)', fontsize=12)
ax_c.set_title('BB84 Secure Key Rate vs QBER\nCCSDS LDPC Reconciliation', fontsize=12)
ax_c.set_xlim(0, 0.15); ax_c.set_ylim(-0.02, 1.02)
ax_c.legend(fontsize=10); ax_c.grid(True, alpha=0.4)
fig_c.tight_layout()
fig_c.savefig(out_dir / 'key_rate_vs_qber.png', dpi=200, bbox_inches='tight')
print(f"Saved: {out_dir / 'key_rate_vs_qber.png'}")

fig_q, ax_q = plt.subplots(figsize=(7, 5))
ax_q.plot(qber_th, shannon, 'k--', linewidth=1.5, label='Shannon limit (f=1.0)')
ax_q.plot(qber_th, theoretical, color='#1a8050', linewidth=2.0,
          label='QC-LDPC irregular rate-0.5 (theoretical)')
ax_q.plot(QBER, QC_KR, 'o', color='#cc2222', markersize=7, zorder=5)
ax_q.plot(QBER, QC_KR, '--', color='#e08080', linewidth=1.2, alpha=0.7,
          label='Simulated (LDPC reconciliation)')
ax_q.axvline(0.11, color='gray', linewidth=1.0, linestyle=':',
             label='BB84 security limit (11%)')
ax_q.set_xlabel('QBER', fontsize=12)
ax_q.set_ylabel('Secure Key Rate (bits/sifted bit)', fontsize=12)
ax_q.set_title('BB84 Secure Key Rate vs QBER\nQC-LDPC Irregular Reconciliation', fontsize=12)
ax_q.set_xlim(0, 0.15); ax_q.set_ylim(-0.02, 1.02)
ax_q.legend(fontsize=10); ax_q.grid(True, alpha=0.4)
fig_q.tight_layout()
fig_q.savefig(out_dir / 'key_rate_vs_qber_qc.png', dpi=200, bbox_inches='tight')
print(f"Saved: {out_dir / 'key_rate_vs_qber_qc.png'}")

# Save combined
fig.savefig(out_dir / 'key_rate_vs_qber_both.png', dpi=200, bbox_inches='tight')
print(f"Saved: {out_dir / 'key_rate_vs_qber_both.png'}")
