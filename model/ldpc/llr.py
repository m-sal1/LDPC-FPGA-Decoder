# LLR computation for BPSK over AWGN
# Moustafa Salman


def compute_llr_awgn(y, sigma):
    # L(y) = 2y / sigma^2 for BPSK with transmitted symbol +1 (bit=0)
    return 2 * y / (sigma ** 2)
