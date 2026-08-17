# LDPC alist file loader
# Moustafa Salman

import numpy as np


def load_alist(filename):
    with open(filename, 'r') as f:
        lines = [list(map(int, line.strip().split())) for line in f]

    n, m = lines[0]          # n = variable nodes, m = check nodes
    max_col_w, max_row_w = lines[1]

    col_weights = lines[2]
    row_weights = lines[3]

    H = np.zeros((m, n), dtype=int)

    # Column connections start at line 4, one row per variable node
    start = 4
    for j in range(n):
        row_indices = lines[start + j]
        for i in row_indices:
            if i != 0:
                H[i - 1, j] = 1  # alist uses 1-based indexing

    check_nodes = [np.where(H[i] == 1)[0] for i in range(m)]
    var_nodes   = [np.where(H[:, j] == 1)[0] for j in range(n)]

    return H, check_nodes, var_nodes
