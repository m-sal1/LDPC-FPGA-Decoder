import random

import cocotb
from cocotb.triggers import Timer


# =========================================================
# PYTHON GOLDEN MODEL
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

        # 0.75 normalization
        attenuated = val - (val >> 2)

        outputs.append(sign * attenuated)

    return outputs


# =========================================================
# RANDOMIZED REGRESSION TEST
# =========================================================

@cocotb.test()
async def cnu_randomized_regression(dut):

    NUM_TESTS = 1000

    print("\n==============================")
    print("CNU RANDOMIZED REGRESSION")
    print("==============================")

    for test_num in range(NUM_TESTS):

        # Generate random signed 8-bit messages
        test_vector = [
            random.randint(-127, 127)
            for _ in range(8)
        ]

        expected = cnu_reference(test_vector)

        # Drive RTL inputs
        for i in range(8):
            dut.msg_in[i].value = test_vector[i]

        # Wait for combinational logic
        await Timer(1, unit="ns")

        # Compare outputs
        for i in range(8):

            rtl_output = dut.msg_out[i].value.to_signed()

            assert rtl_output == expected[i], (
                f"\nMismatch detected!\n"
                f"Test #{test_num}\n"
                f"Input vector: {test_vector}\n"
                f"msg_out[{i}] RTL={rtl_output} "
                f"EXPECTED={expected[i]}"
            )

        # Progress indicator
        if test_num % 100 == 0:
            print(f"Passed {test_num}/{NUM_TESTS}")

    print("\nAll randomized regression tests PASSED.")
