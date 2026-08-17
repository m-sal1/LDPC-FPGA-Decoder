# LDPC information reconciliation for BB84 QKD
# Moustafa Salman

import numpy as np
from model.ldpc.decoder import ldpc_decode
from model.ldpc.quantization import quantize_llr


def qber_to_llr(bob_bits, alice_bits, qber_est, llr_bits=8, scale=2):
    """
    Compute quantised LLRs for LDPC decoding from Bob's bits and the
    estimated QBER. Uses the BSC log-likelihood ratio:
        LLR = +log((1-q)/q) for bit=0, -log((1-q)/q) for bit=1.

    Alice's bits are XORed with Bob's to reduce the problem to decoding
    an error pattern against the all-zero codeword, which is the standard
    approach for systematic linear codes.
    """
    qber_est = np.clip(qber_est, 1e-6, 1 - 1e-6)
    llr_magnitude = np.log((1 - qber_est) / qber_est)

    error_pattern = bob_bits ^ alice_bits
    llr = llr_magnitude * (1 - 2 * error_pattern)

    return quantize_llr(llr, llr_bits, scale)


def reconcile(alice_bits, bob_bits, H, check_nodes, var_nodes,
              qber_est, max_iterations=50, llr_bits=8, scale=2):
    """
    Run LDPC reconciliation: Bob corrects his key to match Alice's.

    Returns bob's corrected bits, whether the syndrome passed, the number
    of iterations used, and the number of remaining bit errors.
    """
    N = H.shape[1]
    assert len(alice_bits) == N and len(bob_bits) == N

    llr_q = qber_to_llr(bob_bits, alice_bits, qber_est, llr_bits, scale)

    decoded_error, iterations = ldpc_decode(
        llr_q, H, check_nodes, var_nodes, max_iterations
    )

    # Recover corrected bits by applying the decoded error pattern
    bob_corrected = alice_bits ^ decoded_error

    syndrome = np.mod(H @ decoded_error, 2)
    success  = bool(np.all(syndrome == 0))

    remaining_errors = int(np.sum(alice_bits != bob_corrected))

    return bob_corrected, success, iterations, remaining_errors
