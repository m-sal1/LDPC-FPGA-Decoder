import random

import cocotb
from cocotb.triggers import Timer


# =========================================================
# PYTHON GOLDEN MODEL
# =========================================================

WIDTH = 8
MAX_VAL = (1 << (WIDTH - 1)) - 1
MIN_VAL = -(1 << (WIDTH - 1))


def saturate(value):

    if value > MAX_VAL:
        return MAX_VAL

    if value < MIN_VAL:
        return MIN_VAL

    return value


def vnu_reference(llr_in, msgs):

    total = llr_in + sum(msgs)

    decision_llr = saturate(total)

    outputs = []

    for i in range(len(msgs)):

        extrinsic = total - msgs[i]

        outputs.append(saturate(extrinsic))

    return outputs, decision_llr


# =========================================================
# RANDOMIZED REGRESSION TEST
# =========================================================

@cocotb.test()
async def vnu_randomized_regression(dut):

    NUM_TESTS = 1000

    print("\n==============================")
    print("VNU RANDOMIZED REGRESSION")
    print("==============================")

    for test_num in range(NUM_TESTS):

        llr_in = random.randint(-127, 127)

        test_vector = [
            random.randint(-127, 127)
            for _ in range(3)
        ]

        expected_outputs, expected_decision = \
            vnu_reference(llr_in, test_vector)

        # -------------------------------------------------
        # DRIVE INPUTS
        # -------------------------------------------------

        dut.llr_in.value = llr_in

        for i in range(3):
            dut.msg_in[i].value = test_vector[i]

        await Timer(1, unit="ns")

        # -------------------------------------------------
        # CHECK EXTRINSIC OUTPUTS
        # -------------------------------------------------

        for i in range(3):

            rtl_output = dut.msg_out[i].value.to_signed()

            assert rtl_output == expected_outputs[i], (
                f"\nMismatch detected!\n"
                f"Test #{test_num}\n"
                f"LLR input: {llr_in}\n"
                f"Input vector: {test_vector}\n"
                f"msg_out[{i}] RTL={rtl_output} "
                f"EXPECTED={expected_outputs[i]}"
            )

        # -------------------------------------------------
        # CHECK DECISION LLR
        # -------------------------------------------------

        rtl_decision = dut.decision_llr.value.to_signed()

        assert rtl_decision == expected_decision, (
            f"\nDecision mismatch!\n"
            f"RTL={rtl_decision} "
            f"EXPECTED={expected_decision}"
        )

        # Progress indicator
        if test_num % 100 == 0:
            print(f"Passed {test_num}/{NUM_TESTS}")

    print("\nAll VNU regression tests PASSED.")
