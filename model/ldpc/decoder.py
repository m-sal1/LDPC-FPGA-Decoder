import numpy as np


def ldpc_decode(llr, H, check_nodes, var_nodes, max_iterations=50):
    M, N = H.shape

    # Enforce integer types for FPGA bit-true simulation
    msg_vc = np.zeros((M, N), dtype=int)
    msg_cv = np.zeros((M, N), dtype=int)

    # Init
    for j in range(N):
        for i in var_nodes[j]:
            msg_vc[i, j] = llr[j]

    for iteration in range(max_iterations):

        # ===== CHECK NODE =====
        for i in range(M):
            connected = check_nodes[i]
            msgs = msg_vc[i, connected]

            # Treat 0 as positive to avoid zeroing out sign_total
            signs = np.where(msgs < 0, -1, 1)
            sign_total = np.prod(signs)

            abs_vals = np.abs(msgs)

            min1 = np.min(abs_vals)
            idx_min = np.argmin(abs_vals)

            tmp = abs_vals.copy()

            # FIX: Use a large integer instead of np.inf to prevent OverflowError
            tmp[idx_min] = 999999
            min2 = np.min(tmp)

            for k, j in enumerate(connected):
                sign = sign_total * signs[k]
                val = min2 if k == idx_min else min1

                # Integer attenuation (approx 0.75 for Normalized Min-Sum)
                attenuated_val = val - (val >> 2)

                msg_cv[i, j] = sign * attenuated_val

        # ===== VARIABLE NODE =====
        for j in range(N):
            connected = var_nodes[j]
            total = llr[j] + np.sum(msg_cv[connected, j])

            for i in connected:
                msg_vc[i, j] = total - msg_cv[i, j]

        # ===== DECISION =====
        decision = np.zeros(N, dtype=int)

        for j in range(N):
            total = llr[j] + np.sum(msg_cv[var_nodes[j], j])
            decision[j] = 0 if total >= 0 else 1

        syndrome = np.mod(H @ decision, 2)

        if np.all(syndrome == 0):
            return decision, iteration + 1

    return decision, max_iterations
