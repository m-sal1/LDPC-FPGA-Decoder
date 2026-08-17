# AWGN channel model for BPSK
# Moustafa Salman

import numpy as np


def awgn_channel(bits, snr_db, rate=0.5):
    x = 1 - 2 * bits  # BPSK mapping: bit 0 -> +1, bit 1 -> -1

    snr_linear = 10 ** (snr_db / 10)

    # Noise variance accounts for code rate in Eb/N0 definition
    sigma = np.sqrt(1 / (2 * rate * snr_linear))

    noise = np.random.normal(0, sigma, size=len(bits))
    y = x + noise

    return y, sigma
