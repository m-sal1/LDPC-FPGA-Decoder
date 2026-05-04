import numpy as np

def load_alist(filename):
    with open(filename, 'r') as f:
        lines = [list(map(int, line.strip().split())) for line in f]

    n, m = lines[0]  # cols, rows
    max_col_w, max_row_w = lines[1]

    col_weights = lines[2]
    row_weights = lines[3]

    H = np.zeros((m, n), dtype=int)

    # Correct offset:
    start = 4

    # Read column connections (n rows)
    for j in range(n):
        row_indices = lines[start + j]
        for i in row_indices:
            if i != 0:
                H[i - 1, j] = 1

    # (row connection part exists but we don't need it)

    check_nodes = [np.where(H[i] == 1)[0] for i in range(m)]
    var_nodes = [np.where(H[:, j] == 1)[0] for j in range(n)]

    return H, check_nodes, var_nodes
