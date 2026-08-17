# QC-LDPC parallel decoder smoke tests
# Moustafa Salman

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

CLOCK_PERIOD_NS = 20      # 50 MHz
LLR_STRONG      = 20
NUM_VN          = 512
MAX_CYCLES      = 500_000


async def reset(dut):
    dut.rst_n.value            = 0
    dut.start.value            = 0
    dut.llr_in.value           = 0
    dut.llr_write_addr.value   = 0
    dut.llr_write_enable.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def load_llrs(dut, llr_vector):
    for addr, val in enumerate(llr_vector):
        dut.llr_write_addr.value   = addr
        dut.llr_in.value           = int(val)
        dut.llr_write_enable.value = 1
        await RisingEdge(dut.clk)
    dut.llr_write_enable.value = 0
    await RisingEdge(dut.clk)


async def wait_done(dut, label, max_cycles=MAX_CYCLES):
    for cycles in range(1, max_cycles + 1):
        await RisingEdge(dut.clk)
        if cycles % 50_000 == 0:
            cocotb.log.info(
                f"[{label}] cycle {cycles} | "
                f"done={int(dut.decoding_done.value)}"
            )
        if dut.decoding_done.value == 1:
            return cycles, False
    return max_cycles, True


async def read_bits(dut):
    bits      = [0] * NUM_VN
    collected = 0
    for _ in range(NUM_VN + 10):
        await RisingEdge(dut.clk)
        if dut.decoded_bit_valid.value == 1:
            addr       = int(dut.decoded_bit_addr.value)
            bits[addr] = int(dut.decoded_bit_out.value)
            collected += 1
            if collected == NUM_VN:
                break
    return bits


@cocotb.test()
async def test_smoke_all_zero(dut):
    """All-zero codeword with strong positive LLRs. Must converge with 0 errors."""
    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())
    await reset(dut)
    await load_llrs(dut, [LLR_STRONG] * NUM_VN)

    cocotb.log.info("Starting all-zero decode.")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles, timed_out = await wait_done(dut, "all_zero")
    assert not timed_out, f"Timed out after {MAX_CYCLES} cycles"
    cocotb.log.info(f"Done at cycle {cycles}")

    await RisingEdge(dut.clk)
    assert int(dut.converged.value) == 1, "converged not asserted"

    bits = await read_bits(dut)
    assert sum(bits) == 0, f"{sum(bits)} bit errors on all-zero codeword"
    cocotb.log.info("ALL-ZERO TEST PASSED")


@cocotb.test()
async def test_smoke_with_errors(dut):
    """4 injected bit errors. Decoder must correct all and converge."""
    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())
    await reset(dut)

    llr_vector      = [LLR_STRONG] * NUM_VN
    error_positions = [10, 101, 233, 300]
    for pos in error_positions:
        llr_vector[pos] = -LLR_STRONG  # negative LLR indicates error

    await load_llrs(dut, llr_vector)
    cocotb.log.info(f"Errors at {error_positions}. Starting decode.")

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycles, timed_out = await wait_done(dut, "with_errors")
    assert not timed_out, f"FSM stuck after {MAX_CYCLES} cycles"

    await RisingEdge(dut.clk)
    assert int(dut.converged.value) == 1, f"Did not converge at cycle {cycles}"

    bits   = await read_bits(dut)
    errors = sum(bits)
    assert errors == 0, f"converged=1 but {errors} errors remain"
    cocotb.log.info(f"ERROR CORRECTION TEST PASSED. Cycles={cycles}")
