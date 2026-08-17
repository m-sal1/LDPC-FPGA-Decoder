"""
model/simulation/run_simulation.py

BER/FER simulation for QC-LDPC n512_k256_z16 (3,6)-regular code.
Saves results to results/qc_*.npy for comparison with CCSDS results.
"""

import numpy as np
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.append(str(PROJECT_ROOT))

from model.ldpc.h_matrix    import load_alist
from model.ldpc.channel     import awgn_channel
from model.ldpc.llr         import compute_llr_awgn
from model.ldpc.quantization import quantize_llr
from model.ldpc.decoder     import ldpc_decode

ALIST_FILE = PROJECT_ROOT / "matrices" / "QC_LDPC_n512_k256_z8_irreg.alist"

CONFIG = {
    "iterations"   : 50,
    "llr_bits"     : 8,
    "scale"        : 2,
    "max_trials"   : 100000,
    "target_errors": 100,
    "snr_values"   : np.linspace(1.0, 4.0, 7),   # Eb/N0 in dB
    "rate"         : 256 / 512,
}


def simulate(H, check_nodes, var_nodes, snr_db):

    N = H.shape[1]

    total_bit_errors = 0
    total_bits       = 0
    frame_errors     = 0
    total_iterations = 0
    trials_run       = 0

    for trial in range(CONFIG["max_trials"]):

        trials_run += 1

        # All-zero codeword (valid for any LDPC code)
        bits = np.zeros(N, dtype=int)

        # AWGN channel
        y, sigma = awgn_channel(bits, snr_db, CONFIG["rate"])

        # LLR computation
        llr   = compute_llr_awgn(y, sigma)
        llr_q = quantize_llr(llr, CONFIG["llr_bits"], CONFIG["scale"])

        # Decode
        decoded, iterations = ldpc_decode(
            llr_q, H, check_nodes, var_nodes, CONFIG["iterations"]
        )

        # Count errors
        bit_errors = int(np.sum(bits != decoded))
        if bit_errors > 0:
            frame_errors += 1

        total_bit_errors += bit_errors
        total_bits       += N
        total_iterations += iterations

        # Progress
        if trial % 1000 == 0 and trial > 0:
            print(
                f"\r  [SNR {snr_db:.1f}dB] "
                f"Trial {trial} | "
                f"FE: {frame_errors}/{CONFIG['target_errors']}",
                end="", flush=True
            )

        # Early stopping
        if frame_errors >= CONFIG["target_errors"]:
            break

    print("\r" + " " * 80 + "\r", end="", flush=True)

    ber      = total_bit_errors / total_bits
    fer      = frame_errors / trials_run
    avg_iter = total_iterations / trials_run

    if frame_errors == 0:
        print(f"  SNR {snr_db:.1f}dB: no errors in {trials_run} trials")

    return ber, fer, avg_iter, trials_run


def main():

    print("=" * 55)
    print("BER/FER SIMULATION — QC-LDPC n512_k256_z16")
    print("(3,6)-regular, girth>=6, full rank=256/256")
    print("=" * 55)

    H, check_nodes, var_nodes = load_alist(ALIST_FILE)
    N = H.shape[1]
    print(f"Matrix loaded: {H.shape[0]} CNs x {N} VNs")
    print(f"Col weight: {min(len(v) for v in var_nodes)}-{max(len(v) for v in var_nodes)}")
    print(f"Row weight: {min(len(c) for c in check_nodes)}-{max(len(c) for c in check_nodes)}")
    print(f"SNR range:  {CONFIG['snr_values'][0]:.1f} - {CONFIG['snr_values'][-1]:.1f} dB")
    print()

    ber_results  = []
    fer_results  = []
    iter_results = []

    print(f"{'Eb/N0':>8} {'BER':>12} {'FER':>8} {'AvgIter':>10} {'Trials':>10}")
    print("-" * 55)

    for snr in CONFIG["snr_values"]:
        ber, fer, avg_iter, trials = simulate(H, check_nodes, var_nodes, snr)
        ber_results.append(ber)
        fer_results.append(fer)
        iter_results.append(avg_iter)
        print(f"{snr:>8.1f} {ber:>12.3e} {fer:>8.4f} {avg_iter:>10.2f} {trials:>10}")

    # Save results
    results_dir = PROJECT_ROOT / "results"
    results_dir.mkdir(exist_ok=True)

    np.save(results_dir / "qc_ber.npy",  np.array(ber_results))
    np.save(results_dir / "qc_fer.npy",  np.array(fer_results))
    np.save(results_dir / "qc_iter.npy", np.array(iter_results))
    np.save(results_dir / "qc_snr.npy",  CONFIG["snr_values"])

    print()
    print(f"Results saved to {results_dir}/qc_*.npy")
    print()
    print("Waterfall summary:")
    for snr, fer in zip(CONFIG["snr_values"], fer_results):
        bar = "█" * int((1 - fer) * 20)
        print(f"  {snr:.1f}dB  FER={fer:.4f}  [{bar:<20}]")


if __name__ == "__main__":
    main()
