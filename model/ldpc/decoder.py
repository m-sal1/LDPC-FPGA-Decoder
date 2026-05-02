import numpy as np

def ldpc_decode(llr, H, check_nodes, var_nodes, max_iterations=50, beta=0.5):

    M, N = H.shape

    msg_vc = np.zeros((M, N))
    msg_cv = np.zeros((M, N))

    # Initialize messages
    for j in range(N):
        for i in var_nodes[j]:
            msg_vc[i, j] = llr[j]

    for iteration in range(max_iterations):

        # Check node update
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

                val = min2 if k == idx_min else min1
                msg_cv[i, j] = sign * max(val - beta, 0)

        # Variable node update
        for j in range(N):
            connected = var_nodes[j]
            total = llr[j] + np.sum(msg_cv[connected, j])

            for i in connected:
                msg_vc[i, j] = total - msg_cv[i, j]

        # Hard decision
        decision = np.zeros(N)

        for j in range(N):
            total = llr[j] + np.sum(msg_cv[var_nodes[j], j])
            decision[j] = 0 if total >= 0 else 1

        # Syndrome check
        syndrome = np.mod(H @ decision, 2)

        if np.all(syndrome == 0):
            return decision.astype(int), iteration + 1

    return decision.astype(int), max_iterations
