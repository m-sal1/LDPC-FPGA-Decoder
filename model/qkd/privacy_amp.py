# Privacy amplification for BB84 QKD
# Moustafa Salman

import numpy as np
import hashlib
import math


def binary_entropy(p):
    p = np.clip(p, 1e-10, 1 - 1e-10)
    return float(-p * math.log2(p) - (1 - p) * math.log2(1 - p))


def secure_key_length(n, qber, reconciliation_efficiency):
    """
    Compute secure key length after privacy amplification.
    Returns (length, key_rate). Length is 0 if QBER is too high.
    """
    h = binary_entropy(qber)
    key_rate = 1 - h - reconciliation_efficiency * h
    l = max(0, int(n * key_rate))
    return l, key_rate


def privacy_amplify(reconciled_key, output_length):
    """
    Hash the reconciled key down to a shorter secure key using SHA-256.

    A real system would use Toeplitz hashing for information-theoretic
    security. SHA-256 is used here as a computationally secure stand-in
    for simulation purposes.
    """
    if output_length == 0:
        return np.array([], dtype=int)

    key_bytes = np.packbits(reconciled_key).tobytes()

    # Hash in rounds with an incrementing salt until we have enough bits
    hash_bits = []
    round_num = 0
    while len(hash_bits) < output_length:
        h = hashlib.sha256(key_bytes + round_num.to_bytes(4, 'big'))
        round_bits = np.unpackbits(np.frombuffer(h.digest(), dtype=np.uint8))
        hash_bits.extend(round_bits.tolist())
        round_num += 1

    return np.array(hash_bits[:output_length], dtype=int)
