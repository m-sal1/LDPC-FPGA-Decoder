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
    "max_trials": 100000,
    "target_errors": 100,
    "snr_values": np.linspace(2, 6, 5),
    "rate": 256 / 512
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

        # All-zero valid codeword
        bits = np.zeros(N, dtype=int)

        # Channel
        y, sigma = awgn_channel(bits, snr_db, CONFIG["rate"])

        # LLR
        llr = compute_llr_awgn(y, sigma)
        llr_q = quantize_llr(
            llr,
            CONFIG["llr_bits"],
            CONFIG["scale"]
        )

        # Decode
        decoded, iterations = ldpc_decode(
            llr_q,
            H,
            check_nodes,
            var_nodes,
            CONFIG["iterations"]
        )

        # Errors
        bit_errors = np.sum(bits != decoded)

        if bit_errors > 0:
            frame_errors += 1

        total_bit_errors += bit_errors
        total_bits += N
        total_iterations += iterations

        # Progress display
        if trial % 1000 == 0 and trial > 0:
            print(
                f"\r  [Running SNR {snr_db:.1f}dB] "
                f"Trial {trial} | "
                f"Frame errors: {frame_errors}/{CONFIG['target_errors']}",
                end="",
                flush=True
            )

        # Early stopping
        if frame_errors >= CONFIG["target_errors"]:
            break

    # Clear progress line
    print("\r" + " " * 100 + "\r", end="", flush=True)

    # Metrics
    ber = total_bit_errors / total_bits
    fer = frame_errors / trials_run
    avg_iter = total_iterations / trials_run

    if frame_errors == 0:
        print(
            f"SNR {snr_db:.1f}dB: "
            f"No errors observed → increase max_trials or lower SNR"
        )

    return ber, fer, avg_iter, trials_run


def main():

    H, check_nodes, var_nodes = load_alist(
        r"C:\Users\moahs\Workspace\LDPC-FPGA-Decoder\matrices\CCSDS_ldpc_n512_k256.alist"
    )

    print("H shape:", H.shape)
    print("Min row weight:", min(len(c) for c in check_nodes))
    print("Min col weight:", min(len(v) for v in var_nodes))

    # =========================
    # RESULT STORAGE
    # =========================

    ber_results = []
    fer_results = []
    iter_results = []

    # =========================
    # RUN SIMULATION
    # =========================

    for snr in CONFIG["snr_values"]:

        ber, fer, avg_iter, trials_run = simulate(
            H,
            check_nodes,
            var_nodes,
            snr
        )

        ber_results.append(ber)
        fer_results.append(fer)
        iter_results.append(avg_iter)

        print(
            f"SNR={snr:.1f}dB  "
            f"BER={ber:.6e}  "
            f"FER={fer:.4f}  "
            f"AvgIter={avg_iter:.2f}  "
            f"(Trials: {trials_run})"
        )

    # =========================
    # SAVE RESULTS
    # =========================

    np.save("results/ber.npy", np.array(ber_results))
    np.save("results/fer.npy", np.array(fer_results))
    np.save("results/iter.npy", np.array(iter_results))
    np.save("results/snr.npy", CONFIG["snr_values"])

    print("\nResults saved successfully.")


if __name__ == "__main__":
    main()
