import numpy as np

def bsc_channel(bits, qber):
    flips = np.random.rand(len(bits)) < qber
    return np.mod(bits + flips, 2)
