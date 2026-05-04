import numpy as np

def quantize_llr(llr, bits=8, scale=2):
    max_val = 2 ** (bits - 1) - 1
    min_val = -max_val

    llr_q = np.round(llr * scale)
    llr_q = np.clip(llr_q, min_val, max_val)

    return llr_q.astype(int)
