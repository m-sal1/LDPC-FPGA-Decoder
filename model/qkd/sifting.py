# Sifting and QBER estimation for BB84
# Moustafa Salman

import numpy as np


def sift_and_estimate(alice_sifted, bob_sifted, sample_fraction=0.1, rng=None):
    """
    Sacrifice a random subset of sifted bits to estimate QBER.
    The remaining bits are passed to reconciliation.

    Returns alice's key, bob's key (both with sample removed), and the
    estimated QBER computed from the sacrificed bits.
    """
    if rng is None:
        rng = np.random.default_rng()

    n = len(alice_sifted)
    n_sample = max(1, int(n * sample_fraction))

    sample_idx = rng.choice(n, n_sample, replace=False)
    keep_idx   = np.setdiff1d(np.arange(n), sample_idx)

    # Count disagreements in the sample to estimate QBER
    qber_est = float(
        np.sum(alice_sifted[sample_idx] != bob_sifted[sample_idx]) / n_sample
    )

    return alice_sifted[keep_idx], bob_sifted[keep_idx], qber_est
