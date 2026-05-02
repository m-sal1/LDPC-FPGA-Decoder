import numpy as np
import matplotlib.pyplot as plt

np.random.seed(0)

# LDPC PARAMETERS

N = 1024
M = 512
row_weight = 6
max_iterations = 50
beta = 0.5

# LDPC MATRIX GENERATION

H = np.zeros((M, N), dtype=int)

for i in range(M):
    cols = np.random.choice(N, row_weight, replace=False)
    H[i, cols] = 1

# sparse graph structures
check_nodes = [np.where(H[i] == 1)[0] for i in range(M)]
var_nodes = [np.where(H[:, j] == 1)[0] for j in range(N)]

# CHANNEL MODEL (BSC)

def bsc_channel(bits, qber):

    flips = np.random.rand(len(bits)) < qber
    return np.mod(bits + flips, 2)

# LLR COMPUTATION

def compute_llr(received, qber):

    L = np.log((1 - qber) / qber)
    return L * (1 - 2 * received)

# FIXED POINT MODEL

def quantize_llr(llr, bits=6):

    scale = 4
    max_val = 2 ** (bits - 1) - 1
    min_val = -max_val

    llr = np.round(llr * scale)
    llr = np.clip(llr, min_val, max_val)

    return llr

# LDPC DECODER
# Offset Min-Sum

def ldpc_decode(llr):

    msg_vc = np.zeros((M, N))
    msg_cv = np.zeros((M, N))

    # initialise variable messages
    for j in range(N):
        for i in var_nodes[j]:
            msg_vc[i, j] = llr[j]

    for iteration in range(max_iterations):

        # CHECK NODE UPDATE

        for i in range(M):

            connected = check_nodes[i]
            msgs = msg_vc[i, connected]

            signs = np.sign(msgs)
            sign_total = np.prod(signs)

            abs_vals = np.abs(msgs)

            min1 = np.min(abs_vals)
            idx_min = np.argmin(abs_vals)

            tmp = abs_vals.copy()
            tmp[idx_min] = np.inf
            min2 = np.min(tmp)

            for k, j in enumerate(connected):

                sign = sign_total * signs[k]

                if k == idx_min:
                    val = min2
                else:
                    val = min1

                msg_cv[i, j] = sign * max(val - beta, 0)

        # VARIABLE NODE UPDATE

        for j in range(N):

            connected = var_nodes[j]

            total = llr[j] + np.sum(msg_cv[connected, j])

            for i in connected:
                msg_vc[i, j] = total - msg_cv[i, j]

        # HARD DECISION

        decision = np.zeros(N)

        for j in range(N):
            total = llr[j] + np.sum(msg_cv[var_nodes[j], j])
            decision[j] = 0 if total >= 0 else 1

        # SYNDROME CHECK

        syndrome = np.mod(H @ decision, 2)

        if np.all(syndrome == 0):
            return decision, iteration + 1

    return decision, max_iterations

# SIMULATION

def simulate(qber, trials=200):

    total_bit_errors = 0
    total_bits = 0

    frame_errors = 0
    total_iterations = 0

    for _ in range(trials):

        bits = np.zeros(N)

        noisy = bsc_channel(bits, qber)

        llr = compute_llr(noisy, qber)
        llr = quantize_llr(llr)

        decoded, iterations = ldpc_decode(llr)

        bit_errors = np.sum(bits != decoded)

        if bit_errors > 0:
            frame_errors += 1

        total_bit_errors += bit_errors
        total_bits += N
        total_iterations += iterations

    ber = total_bit_errors / total_bits
    fer = frame_errors / trials
    avg_iter = total_iterations / trials

    return ber, fer, avg_iter

# RUN EXPERIMENT

qber_values = np.linspace(0.01, 0.06, 6)

ber_results = []
fer_results = []
iter_results = []

for q in qber_values:

    ber, fer, avg_iter = simulate(q)

    ber_results.append(ber)
    fer_results.append(fer)
    iter_results.append(avg_iter)

    print(f"QBER={q:.2f}  BER={ber:.6e}  FER={fer:.4f}  AvgIter={avg_iter:.2f}")

# PLOTS

plt.figure()
plt.semilogy(qber_values, ber_results, marker='o')
plt.xlabel("QBER")
plt.ylabel("Residual BER")
plt.title("LDPC Decoder Performance")
plt.grid(True)

plt.figure()
plt.plot(qber_values, fer_results, marker='o')
plt.xlabel("QBER")
plt.ylabel("Frame Error Rate")
plt.title("FER vs QBER")
plt.grid(True)

plt.figure()
plt.plot(qber_values, iter_results, marker='o')
plt.xlabel("QBER")
plt.ylabel("Average Iterations")
plt.title("Decoder Iterations vs QBER")
plt.grid(True)

plt.show()
