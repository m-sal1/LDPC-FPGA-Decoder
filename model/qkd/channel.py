# BB84 quantum channel simulation
# Moustafa Salman

import numpy as np


def simulate_bb84_sifting(n_raw, qber, rng=None):
    """
    Simulate BB84 raw key generation and basis sifting.

    Alice and Bob each pick random bases independently. They keep only
    the bits where their bases match (roughly half), giving the sifted key.
    Channel errors are modelled as a binary symmetric channel with
    crossover probability qber.

    Returns alice's sifted bits, bob's sifted bits (with errors), and
    the sifted key length.
    """
    if rng is None:
        rng = np.random.default_rng()

    alice_bits  = rng.integers(0, 2, n_raw)
    alice_bases = rng.integers(0, 2, n_raw)  # 0 = rectilinear, 1 = diagonal
    bob_bases   = rng.integers(0, 2, n_raw)

    # Sifting: discard bits where bases disagree
    matching     = alice_bases == bob_bases
    alice_sifted = alice_bits[matching]

    # Introduce channel errors
    errors     = rng.random(len(alice_sifted)) < qber
    bob_sifted = alice_sifted ^ errors.astype(int)

    return alice_sifted, bob_sifted, len(alice_sifted)


def estimate_qber(alice_sample, bob_sample):
    """
    Estimate QBER from a publicly revealed subset of sifted bits.
    In practice around 10% of sifted bits are sacrificed for this.
    """
    if len(alice_sample) == 0:
        return 0.0
    return float(np.sum(alice_sample != bob_sample) / len(alice_sample))
