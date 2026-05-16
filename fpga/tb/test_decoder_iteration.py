import random

import cocotb
from cocotb.triggers import Timer


WIDTH = 8
MAX_VAL = (1 << (WIDTH - 1)) - 1
MIN_VAL = -(1 << (WIDTH - 1))


# =========================================================
# SATURATION
# =========================================================

def saturate(value):

    if value > MAX_VAL:
        return MAX_VAL

    if value < MIN_VAL:
        return MIN_VAL

    return value


# =========================================================
# CNU REFERENCE
# =========================================================

def cnu_reference(msgs):

    signs = [-1 if x < 0 else 1 for x in msgs]

    abs_vals = [abs(x) for x in msgs]

    sign_total = 1

    for s in signs:
        sign_total *= s

    min1 = min(abs_vals)
    idx_min = abs_vals.index(min1)

    tmp = abs_vals.copy()
    tmp[idx_min] = 999999

    min2 = min(tmp)

    outputs = []

    for i in range(len(msgs)):

        sign = sign_total * signs[i]

        val = min2 if i == idx_min else min1

        attenuated = val - (val >> 2)

        outputs.append(sign * attenuated)

    return outputs


# =========================================================
# VNU REFERENCE
# =========================================================

def vnu_reference(llr_in, msgs):

    total = llr_in + sum(msgs)

    decision_llr = saturate(total)

    outputs = []

    for i in range(len(msgs)):

        extrinsic = total - msgs[i]

        outputs.append(saturate(extrinsic))

    return outputs, decision_llr


# =========================================================
# FULL ITERATION REFERENCE
# =========================================================

def iteration_reference(llr_in, vn_to_cn):

    cnu_out = cnu_reference(vn_to_cn)

    updated_msgs, decision_llr = \
        vnu_reference(llr_in, cnu_out)

    return cnu_out, updated_msgs, decision_llr


# =========================================================
# RANDOMIZED REGRESSION
# =========================================================

@cocotb.test()
async def decoder_iteration_regression(dut):

    NUM_TESTS = 1000

    print("\n====================================")
    print("DECODER ITERATION REGRESSION")
    print("====================================")

    for test_num in range(NUM_TESTS):

        llr_in = random.randint(-127, 127)

        vn_to_cn = [
            random.randint(-127, 127)
            for _ in range(8)
        ]

        expected_cnu, expected_vnu, expected_decision = \
            iteration_reference(llr_in, vn_to_cn)

        # -------------------------------------------------
        # DRIVE INPUTS
        # -------------------------------------------------

        dut.llr_in.value = llr_in

        for i in range(8):
            dut.vn_to_cn[i].value = vn_to_cn[i]

        await Timer(1, unit="ns")

        # -------------------------------------------------
        # CHECK CNU OUTPUTS
        # -------------------------------------------------

        for i in range(8):

            rtl_cnu = dut.cn_to_vn[i].value.to_signed()

            assert rtl_cnu == expected_cnu[i], (
                f"\nCNU mismatch!\n"
                f"Test #{test_num}\n"
                f"RTL={rtl_cnu} "
                f"EXPECTED={expected_cnu[i]}"
            )

        # -------------------------------------------------
        # CHECK UPDATED VNU OUTPUTS
        # -------------------------------------------------

        for i in range(8):

            rtl_vnu = dut.updated_vn_to_cn[i].value.to_signed()

            assert rtl_vnu == expected_vnu[i], (
                f"\nVNU mismatch!\n"
                f"Test #{test_num}\n"
                f"RTL={rtl_vnu} "
                f"EXPECTED={expected_vnu[i]}"
            )

        # -------------------------------------------------
        # CHECK FINAL DECISION
        # -------------------------------------------------

        rtl_decision = dut.decision_llr.value.to_signed()

        assert rtl_decision == expected_decision, (
            f"\nDecision mismatch!\n"
            f"RTL={rtl_decision} "
            f"EXPECTED={expected_decision}"
        )

        if test_num % 100 == 0:
            print(f"Passed {test_num}/{NUM_TESTS}")

    print("\nAll decoder iteration regression tests PASSED.")
