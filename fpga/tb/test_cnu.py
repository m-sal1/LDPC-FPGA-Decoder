# CNU randomised regression testbench (4-stage pipeline)
# Moustafa Salman

import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

WIDTH   = 8
DEGREE  = 8
MAX_VAL =  (1 << (WIDTH-1)) - 1
MIN_VAL = -(1 << (WIDTH-1))


def cnu_reference(msgs):
    signs = [1 if m < 0 else 0 for m in msgs]
    overall_sign = 0
    for s in signs:
        overall_sign ^= s
    abs_vals = [abs(m) for m in msgs]
    sorted_abs = sorted(enumerate(abs_vals), key=lambda x: x[1])
    min1_idx = sorted_abs[0][0]
    min1     = sorted_abs[0][1]
    min2     = sorted_abs[1][1]
    outputs = []
    for i in range(DEGREE):
        sign = overall_sign ^ signs[i]
        val  = min2 if i == min1_idx else min1
        att  = val - (val >> 2)
        out  = -att if sign else att
        out  = max(MIN_VAL, min(MAX_VAL, out))
        outputs.append(out)
    return outputs


@cocotb.test()
async def cnu_randomized_regression(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value      = 1
    dut.valid_in.value = 0
    for i in range(DEGREE):
        dut.msg_in[i].value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    print("\n==============================")
    print("CNU RANDOMIZED REGRESSION")
    print("(4-stage pipeline)")
    print("==============================")

    NUM_TESTS = 1000
    for test_num in range(NUM_TESTS):
        msgs = [random.randint(MIN_VAL+1, MAX_VAL) for _ in range(DEGREE)]
        expected = cnu_reference(msgs)

        for i in range(DEGREE):
            dut.msg_in[i].value = msgs[i]
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0

        # Wait 4 cycles for 4-stage pipeline
        for _ in range(4):
            await RisingEdge(dut.clk)

        assert dut.valid_out.value == 1, \
            f"Test {test_num}: valid_out not asserted after 4 cycles"

        for i in range(DEGREE):
            rtl = dut.msg_out[i].value.to_signed()
            assert rtl == expected[i], \
                f"Test {test_num}: msg_out[{i}] RTL={rtl} EXPECTED={expected[i]}, msgs={msgs}"

        if test_num % 100 == 0:
            print(f"  Passed {test_num}/{NUM_TESTS}")

    print("All CNU regression tests PASSED.")
