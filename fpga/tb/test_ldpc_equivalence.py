"""
test_ldpc_equivalence.py

Bit-exact Python vs RTL equivalence test.
Runs the Python reference decoder and the RTL decoder on the same
LLR vector and checks that the decoded bits match exactly.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

import sys
from pathlib import Path
import numpy as np

# ── Project imports ───────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.append(str(PROJECT_ROOT))

from model.ldpc.h_matrix import load_alist
from model.ldpc.decoder  import ldpc_decode

ALIST_PATH      = PROJECT_ROOT / "matrices" / "CCSDS_ldpc_n512_k256.alist"
CLOCK_PERIOD_NS = 40      # 25 MHz
NUM_VN          = 512
MAX_CYCLES      = 500000


# ── Helpers ───────────────────────────────────────────────────────────────────

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


async def read_decoded_bits(dut):
    bits = [0] * NUM_VN
    collected = 0
    for _ in range(NUM_VN + 10):
        await RisingEdge(dut.clk)
        if dut.decoded_bit_valid.value == 1:
            addr = int(dut.decoded_bit_addr.value)
            bit  = int(dut.decoded_bit_out.value)
            bits[addr] = bit
            collected += 1
            if collected == NUM_VN:
                break
    return np.array(bits, dtype=int)


# ── Test ──────────────────────────────────────────────────────────────────────

@cocotb.test()
async def test_python_rtl_equivalence(dut):

    cocotb.start_soon(Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start())

    # ── Load matrix ───────────────────────────────────────────────────────────
    H, check_nodes, var_nodes = load_alist(ALIST_PATH)
    cocotb.log.info(f"Loaded CCSDS matrix: {H.shape}")

    # ── Build test LLR vector ─────────────────────────────────────────────────
    # All-zero codeword + 4 injected errors (negative LLRs)
    llr_vector      = np.full(NUM_VN, 20, dtype=int)
    error_positions = [10, 57, 101, 233]
    for pos in error_positions:
        llr_vector[pos] = -20

    cocotb.log.info(f"Injected errors at: {error_positions}")

    # ── Run Python decoder ────────────────────────────────────────────────────
    python_bits, python_iters = ldpc_decode(
        llr=llr_vector,
        H=H,
        check_nodes=check_nodes,
        var_nodes=var_nodes,
        max_iterations=50
    )

    python_syndrome = np.mod(H @ python_bits, 2)
    python_valid    = bool(np.all(python_syndrome == 0))

    cocotb.log.info(f"Python decoder: {python_iters} iterations, "
                    f"syndrome {'PASS' if python_valid else 'FAIL'}")
    cocotb.log.info(f"Python first 16 bits: {python_bits[:16].tolist()}")

    # ── Reset and load LLRs into RTL ─────────────────────────────────────────
    await reset(dut)
    await load_llrs(dut, llr_vector)
    cocotb.log.info("RTL LLR bank loaded.")

    # ── Start RTL decode ──────────────────────────────────────────────────────
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # ── Wait for completion ───────────────────────────────────────────────────
    cycles = 0
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        cycles += 1

        # Periodic progress
        if cycles % 10000 == 0:
            cocotb.log.info(f"  Waiting... cycle {cycles}")

        if dut.decoding_done.value == 1:
            break
    else:
        assert False, f"RTL decoder never completed within {MAX_CYCLES} cycles"

    rtl_converged = int(dut.converged.value)
    cocotb.log.info(f"RTL completed at cycle {cycles}, "
                    f"converged={rtl_converged}")

    # ── Read back decoded bits ────────────────────────────────────────────────
    rtl_bits = await read_decoded_bits(dut)
    cocotb.log.info(f"RTL first 16 bits: {rtl_bits[:16].tolist()}")

    # ── Compare ───────────────────────────────────────────────────────────────
    mismatches = np.where(python_bits != rtl_bits)[0]
    cocotb.log.info(f"Bit mismatches Python vs RTL: {len(mismatches)}")

    if len(mismatches) > 0:
        cocotb.log.warning(
            f"First 10 mismatch positions: {mismatches[:10].tolist()}"
        )
        cocotb.log.warning(
            f"Python at those positions: {python_bits[mismatches[:10]].tolist()}"
        )
        cocotb.log.warning(
            f"RTL    at those positions: {rtl_bits[mismatches[:10]].tolist()}"
        )

    assert rtl_converged == 1, \
        "RTL decoder did not converge — syndrome check failed"

    assert len(mismatches) == 0, \
        (f"Python/RTL mismatch: {len(mismatches)} bits differ. "
         f"First mismatch at index {mismatches[0]}")

    cocotb.log.info("Python <-> RTL equivalence VERIFIED.")
