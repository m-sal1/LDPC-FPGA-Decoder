import numpy as np

def compute_llr_bsc(received, qber):
    L = np.log((1 - qber) / qber)
    return L * (1 - 2 * received)
