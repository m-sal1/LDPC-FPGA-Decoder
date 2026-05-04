import numpy as np

from model.ldpc.h_matrix import load_alist
from model.ldpc.channel import awgn_channel
from model.ldpc.llr import compute_llr_awgn
from model.ldpc.quantization import quantize_llr
from model.ldpc.decoder import ldpc_decode

CONFIG = {
    "iterations": 100,
    "llr_bits": 8,
    "scale": 2,
    "max_trials": 100000,  # Absolute maximum frames to simulate per SNR
    "target_errors": 100,  # Stop early once we hit 100 frame errors
    "snr_values": np.linspace(2, 6, 5),
    "rate": 256 / 512  # k/n for CCSDS n512_k256
}


def simulate(H, check_nodes, var_nodes, snr_db):
    N = H.shape[1]

    total_bit_errors = 0
    total_bits = 0
    frame_errors = 0
    total_iterations = 0
    trials_run = 0

    for trial in range(CONFIG["max_trials"]):
        trials_run += 1

        bits = np.zeros(N, dtype=int)

        y, sigma = awgn_channel(bits, snr_db, CONFIG["rate"])
        llr = compute_llr_awgn(y, sigma)
        llr_q = quantize_llr(llr, CONFIG["llr_bits"], CONFIG["scale"])

        decoded, iterations = ldpc_decode(
            llr_q,
            H,
            check_nodes,
            var_nodes,
            CONFIG["iterations"]
        )

        bit_errors = np.sum(bits != decoded)

        if bit_errors > 0:
            frame_errors += 1

        total_bit_errors += bit_errors
        total_bits += N
        total_iterations += iterations

        # --- THE TWEAK: In-place terminal updating ---
        if trial % 1000 == 0 and trial > 0:
            # \r sends the cursor back to the start of the line.
            # end="" prevents moving to the next line. flush=True forces the terminal to draw it immediately.
            print(
                f"\r  [Running SNR {snr_db:.1f}dB] Trial {trial} | Frame errors: {frame_errors}/{CONFIG['target_errors']}",
                end="", flush=True)

        if frame_errors >= CONFIG["target_errors"]:
            break

    # Clear the loading line before returning so the main() print looks perfectly clean
    print("\r" + " " * 80 + "\r", end="", flush=True)

    ber = total_bit_errors / total_bits
    fer = frame_errors / trials_run
    avg_iter = total_iterations / trials_run

    if frame_errors == 0:
        print(f"SNR {snr_db:.1f}dB: No errors observed → increase max_trials or lower SNR")

    return ber, fer, avg_iter, trials_run

def main():
    H, check_nodes, var_nodes = load_alist(
        r"C:\Users\moahs\Workspace\LDPC-FPGA-Decoder\matrices\CCSDS_ldpc_n512_k256.alist"
    )

    print("H shape:", H.shape)
    print("Min row weight:", min(len(c) for c in check_nodes))
    print("Min col weight:", min(len(v) for v in var_nodes))

    for snr in CONFIG["snr_values"]:
        ber, fer, avg_iter, trials_run = simulate(H, check_nodes, var_nodes, snr)

        print(f"SNR={snr:.1f}dB  BER={ber:.6e}  FER={fer:.4f}  AvgIter={avg_iter:.2f}  (Trials: {trials_run})")


if __name__ == "__main__":
    main()
