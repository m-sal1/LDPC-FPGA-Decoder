# Unified cocotb/Verilator Makefile for LDPC-FPGA-Decoder
# Moustafa Salman
#
# Usage:
#   make MODE=ccsds      CCSDS serial decoder smoke tests
#   make MODE=ccsds_eq   CCSDS Python-RTL equivalence test
#   make MODE=qc         QC-LDPC parallel decoder smoke tests
#   make MODE=cnu        CNU unit test
#   make MODE=vnu        VNU unit test

MODE ?= ccsds

TOPLEVEL_LANG = verilog
SIM           = verilator
EXTRA_ARGS    = --trace --timing -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-UNSIGNED

ifeq ($(MODE),ccsds)
VERILOG_SOURCES = \
    ../rtl/llr_bank.sv \
    ../rtl/edge_message_bank.sv \
    ../rtl/cn_rom.sv \
    ../rtl/vn_rom.sv \
    ../rtl/vn_degree_rom.sv \
    ../rtl/cnu.sv \
    ../rtl/vnu.sv \
    ../rtl/syndrome_checker.sv \
    ../rtl/iteration_controller.sv \
    ../rtl/ldpc_decoder_top.sv
TOPLEVEL = ldpc_decoder_top
MODULE   = test_ldpc_decoder_top
endif

ifeq ($(MODE),ccsds_eq)
VERILOG_SOURCES = \
    ../rtl/llr_bank.sv \
    ../rtl/edge_message_bank.sv \
    ../rtl/cn_rom.sv \
    ../rtl/vn_rom.sv \
    ../rtl/vn_degree_rom.sv \
    ../rtl/cnu.sv \
    ../rtl/vnu.sv \
    ../rtl/syndrome_checker.sv \
    ../rtl/iteration_controller.sv \
    ../rtl/ldpc_decoder_top.sv
TOPLEVEL = ldpc_decoder_top
MODULE   = test_ldpc_equivalence
endif

ifeq ($(MODE),qc)
VERILOG_SOURCES = \
    ../rtl/qc_llr_bank.sv \
    ../rtl/qc_vc_bank.sv \
    ../rtl/qc_cv_bank.sv \
    ../rtl/barrel_shifter.sv \
    ../rtl/qc_cn_rom.sv \
    ../rtl/qc_vn_rom.sv \
    ../rtl/qc_vn_cn_slot_rom.sv \
    ../rtl/qc_row_weight_rom.sv \
    ../rtl/qc_col_weight_rom.sv \
    ../rtl/cnu.sv \
    ../rtl/vnu.sv \
    ../rtl/syndrome_checker.sv \
    ../rtl/qc_iteration_controller.sv \
    ../rtl/qc_ldpc_decoder_top.sv
TOPLEVEL = qc_ldpc_decoder_top
MODULE   = test_qc_ldpc_decoder_top
endif

ifeq ($(MODE),cnu)
VERILOG_SOURCES = ../rtl/cnu.sv
TOPLEVEL        = cnu
MODULE          = test_cnu
endif

ifeq ($(MODE),vnu)
VERILOG_SOURCES = ../rtl/vnu.sv
TOPLEVEL        = vnu
MODULE          = test_vnu
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
