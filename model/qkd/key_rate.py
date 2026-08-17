# Secure key rate and reconciliation efficiency calculations
# Moustafa Salman

import numpy as np
import math


def binary_entropy(p):
    p = np.clip(float(p), 1e-10, 1 - 1e-10)
    return -p * math.log2(p) - (1 - p) * math.log2(1 - p)


def measure_reconciliation_efficiency(qber, code_rate=0.5):
    """
    Compute reconciliation efficiency f = (1 - R) / h(QBER).
    f = 1.0 is the Shannon limit; higher means more bits leaked.
    """
    h = binary_entropy(qber)
    if h == 0:
        return float('inf')
    return (1 - code_rate) / h


def compute_key_rate(qber, f):
    """
    Secure key rate per sifted bit: r = 1 - (1 + f) * h(QBER).
    Returns 0 if the rate would be negative.
    """
    h = binary_entropy(qber)
    return max(0.0, 1 - (1 + f) * h)


def analyse_key_rates(qber_values, code_rate=0.5):
    """
    Compute key rate metrics across a range of QBER values.
    Returns a dict of arrays suitable for plotting.
    """
    results = {
        'qber'     : np.array(qber_values),
        'h_qber'   : np.array([binary_entropy(q) for q in qber_values]),
        'f'        : np.array([measure_reconciliation_efficiency(q, code_rate)
                               for q in qber_values]),
        'key_rate' : np.zeros(len(qber_values)),
        'secure'   : np.zeros(len(qber_values), dtype=bool),
    }

    for i, (q, f) in enumerate(zip(qber_values, results['f'])):
        r = compute_key_rate(q, f)
        results['key_rate'][i] = r
        results['secure'][i]   = r > 0

    return results
