# LDPC min-sum decoder (bit-true Python reference model)
# Moustafa Salman

import numpy as np


def ldpc_decode(llr, H, check_nodes, var_nodes, max_iterations=50):
    M, N = H.shape

    # Integer messages to match fixed-point RTL behaviour
    msg_vc = np.zeros((M, N), dtype=int)  # variable-to-check
    msg_cv = np.zeros((M, N), dtype=int)  # check-to-variable

    # Initialise VN->CN messages from channel LLRs
    for j in range(N):
        for i in var_nodes[j]:
            msg_vc[i, j] = llr[j]

    for iteration in range(max_iterations):

        # Check node update (Normalised Min-Sum)
        for i in range(M):
            connected = check_nodes[i]
            msgs = msg_vc[i, connected]

            # Treat zero as positive - matches RTL sign-bit convention
            signs = np.where(msgs < 0, -1, 1)
            sign_total = np.prod(signs)

            abs_vals = np.abs(msgs)
            min1 = np.min(abs_vals)
            idx_min = np.argmin(abs_vals)

            # Second minimum - use large integer instead of inf to avoid overflow
            tmp = abs_vals.copy()
            tmp[idx_min] = 999999
            min2 = np.min(tmp)

            for k, j in enumerate(connected):
                sign = sign_total * signs[k]
                val = min2 if k == idx_min else min1

                # Scale by 0.75 using integer arithmetic: v - (v >> 2)
                # Matches the RTL attenuation with no DSP multiplier
                attenuated_val = val - (val >> 2)

                msg_cv[i, j] = sign * attenuated_val

        # Variable node update
        for j in range(N):
            connected = var_nodes[j]
            total = llr[j] + np.sum(msg_cv[connected, j])

            # Extrinsic message: subtract own contribution
            for i in connected:
                msg_vc[i, j] = total - msg_cv[i, j]

        # Hard decision and syndrome check
        decision = np.zeros(N, dtype=int)
        for j in range(N):
            total = llr[j] + np.sum(msg_cv[var_nodes[j], j])
            decision[j] = 0 if total >= 0 else 1

        syndrome = np.mod(H @ decision, 2)
        if np.all(syndrome == 0):
            return decision, iteration + 1

    return decision, max_iterations