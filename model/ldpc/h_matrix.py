import numpy as np

def generate_ldpc_matrix(M, N, row_weight, seed=0):
    np.random.seed(seed)
    H = np.zeros((M, N), dtype=int)

    for i in range(M):
        cols = np.random.choice(N, row_weight, replace=False)
        H[i, cols] = 1

    check_nodes = [np.where(H[i] == 1)[0] for i in range(M)]
    var_nodes = [np.where(H[:, j] == 1)[0] for j in range(N)]

    return H, check_nodes, var_nodes
