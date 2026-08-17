# VNU randomised regression testbench (degrees 3, 4, 5 for CCSDS)
# Moustafa Salman

import random
import cocotb
from cocotb.triggers import Timer

WIDTH   = 8
DEGREE  = 5
MAX_VAL =  (1 << (WIDTH - 1)) - 1
MIN_VAL = -(1 << (WIDTH - 1))


def saturate(value):
    return max(MIN_VAL, min(MAX_VAL, value))


def vnu_reference(llr_in, msgs, degree):
    """
    Golden model for the variable node update.
    Only the first `degree` message slots are active; unused slots are 0.
    Returns extrinsic outputs for all DEGREE slots and the decision LLR.
    """
    total        = llr_in + sum(msgs[:degree])
    decision_llr = saturate(total)

    outputs = []
    for i in range(degree):
        outputs.append(saturate(total - msgs[i]))  # extrinsic = total minus own message

    # Unused slots output 0
    for _ in range(DEGREE - degree):
        outputs.append(0)

    return outputs, decision_llr


@cocotb.test()
async def vnu_randomized_regression(dut):
    NUM_TESTS  = 1000
    VALID_DEGS = [3, 4, 5]  # degree distribution in CCSDS n512_k256

    for test_num in range(NUM_TESTS):
        degree = random.choice(VALID_DEGS)
        llr_in = random.randint(-127, 127)

        # Active messages padded with zeros for unused slots
        valid_msgs = [random.randint(-127, 127) for _ in range(degree)]
        all_msgs   = valid_msgs + [0] * (DEGREE - degree)

        expected_outputs, expected_decision = vnu_reference(llr_in, all_msgs, degree)

        dut.llr_in.value = llr_in
        dut.degree.value = degree
        for i in range(DEGREE):
            dut.msg_in[i].value = all_msgs[i]

        await Timer(1, unit="ns")

        for i in range(DEGREE):
            rtl = dut.msg_out[i].value.to_signed()
            assert rtl == expected_outputs[i], (
                f"Test {test_num}: msg_out[{i}] RTL={rtl} "
                f"expected={expected_outputs[i]} "
                f"degree={degree} llr={llr_in} msgs={all_msgs}"
            )

        rtl_dec = dut.decision_llr.value.to_signed()
        assert rtl_dec == expected_decision, (
            f"Test {test_num}: decision_llr RTL={rtl_dec} "
            f"expected={expected_decision} "
            f"degree={degree} llr={llr_in} msgs={all_msgs}"
        )

        if test_num % 100 == 0:
            print(f"  Passed {test_num}/{NUM_TESTS} (degree={degree})")

    print("All VNU regression tests PASSED.")
