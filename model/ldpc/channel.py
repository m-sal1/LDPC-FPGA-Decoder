import numpy as np


def awgn_channel(bits, snr_db, rate=0.5):
    x = 1 - 2 * bits  # BPSK

    snr_linear = 10 ** (snr_db / 10)

    # FIX 3: Include code rate for proper Eb/N0 calculation
    sigma = np.sqrt(1 / (2 * rate * snr_linear))

    noise = np.random.normal(0, sigma, size=len(bits))
    y = x + noise

    return y, sigma
