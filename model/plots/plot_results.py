import numpy as np
import matplotlib.pyplot as plt

qber = np.load("results/qber.npy")
ber = np.load("results/ber.npy")
fer = np.load("results/fer.npy")
iters = np.load("results/iter.npy")

plt.figure()
plt.semilogy(qber, ber, marker='o')
plt.xlabel("QBER")
plt.ylabel("Residual BER")
plt.title("LDPC BER vs QBER")
plt.grid(True)
plt.savefig("results/ber.png", dpi=300)

plt.figure()
plt.plot(qber, fer, marker='o')
plt.xlabel("QBER")
plt.ylabel("FER")
plt.title("Frame Error Rate")
plt.grid(True)
plt.savefig("results/fer.png", dpi=300)

plt.figure()
plt.plot(qber, iters, marker='o')
plt.xlabel("QBER")
plt.ylabel("Avg Iterations")
plt.title("Iterations vs QBER")
plt.grid(True)
plt.savefig("results/iterations.png", dpi=300)

plt.show()
