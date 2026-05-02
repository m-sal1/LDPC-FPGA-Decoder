import numpy as np
import os

from model.ldpc.h_matrix import generate_ldpc_matrix
from model.ldpc.channel import bsc_channel
from model.ldpc.llr import compute_llr_bsc
from model.ldpc.quantization import quantize_llr
from model.ldpc.decoder import ldpc_decode

# CONFIG

CONFIG = {
    "N": 1024,
    "M": 512,
    "row_weight": 6,
    "iterations": 50,
    "beta": 0.5,
    "llr_bits": 6,
    "scale": 4,
    "trials": 200,
    "qber_values": np.linspace(0.01, 0.06, 6)
}

# =========================

def simulate(H, check_nodes, var_nodes, qber):

    total_bit_errors = 0
    total_bits = 0
    frame_errors = 0
    total_iterations = 0

    for _ in range(CONFIG["trials"]):

        bits = np.zeros(CONFIG["N"])

        noisy = bsc_channel(bits, qber)

        llr = compute_llr_bsc(noisy, qber)
        llr_q = quantize_llr(llr, CONFIG["llr_bits"], CONFIG["scale"])

        decoded, iterations = ldpc_decode(
            llr_q,
            H,
            check_nodes,
            var_nodes,
            CONFIG["iterations"],
            CONFIG["beta"]
        )

        bit_errors = np.sum(bits != decoded)

        if bit_errors > 0:
            frame_errors += 1

        total_bit_errors += bit_errors
        total_bits += CONFIG["N"]
        total_iterations += iterations

    ber = total_bit_errors / total_bits
    fer = frame_errors / CONFIG["trials"]
    avg_iter = total_iterations / CONFIG["trials"]

    return ber, fer, avg_iter

# =========================

def main():

    os.makedirs("results", exist_ok=True)
    os.makedirs("sim/vectors", exist_ok=True)

    H, check_nodes, var_nodes = generate_ldpc_matrix(
        CONFIG["M"],
        CONFIG["N"],
        CONFIG["row_weight"]
    )

    ber_results = []
    fer_results = []
    iter_results = []

    for q in CONFIG["qber_values"]:

        ber, fer, avg_iter = simulate(H, check_nodes, var_nodes, q)

        ber_results.append(ber)
        fer_results.append(fer)
        iter_results.append(avg_iter)

        print(f"QBER={q:.2f}  BER={ber:.6e}  FER={fer:.4f}  AvgIter={avg_iter:.2f}")

    # Save results
    np.save("results/ber.npy", ber_results)
    np.save("results/fer.npy", fer_results)
    np.save("results/iter.npy", iter_results)
    np.save("results/qber.npy", CONFIG["qber_values"])

    # Generate one test vector for FPGA
    bits = np.zeros(CONFIG["N"])
    noisy = bsc_channel(bits, CONFIG["qber_values"][0])
    llr = compute_llr_bsc(noisy, CONFIG["qber_values"][0])
    llr_q = quantize_llr(llr, CONFIG["llr_bits"], CONFIG["scale"])

    decoded, _ = ldpc_decode(llr_q, H, check_nodes, var_nodes)

    np.savetxt("sim/vectors/llr_input.txt", llr_q, fmt="%d")
    np.savetxt("sim/vectors/expected_output.txt", decoded, fmt="%d")

if __name__ == "__main__":
    main()
