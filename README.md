# LDPC-FPGA-Decoder

Two LDPC decoders on Intel Cyclone V (DE1-SoC) for QKD information reconciliation.  
MSc Dissertation — University of Leeds, ELEC5882M.

| | CCSDS Serial | QC-LDPC Parallel |
|---|---|---|
| Throughput | 1.10 Mbps | 7.5 Mbps |
| ALMs | 1,426 / 32,070 (4%) | 15,181 / 32,070 (47%) |
| Setup slack | +13.1 ns | +11.5 ns |
| Board verified | ✓ | ✓ |

---

## Simulation GUI

Run directly:
```bash
pip install numpy PySide6 matplotlib
python gui/sim_gui.py
```

Or use `Reconciler/Reconciler.exe` — no Python required.

---

## RTL Verification (cocotb)

Requires Verilator 5.036+ and WSL.

```bash
source .venv-wsl/bin/activate
cd fpga/tb
make MODE=ccsds    # CCSDS serial decoder
make MODE=qc       # QC-LDPC parallel decoder
```

Expected: `TESTS=2 PASS=2 FAIL=0` for both.

---

## Regenerate ROM files

```bash
python -m model.tools.generate_qc_ldpc
copy fpga\rtl\qc_*.mem fpga\quartus\
```

---

## Synthesis

Open in Quartus Prime Lite 22.1:
- `fpga/quartus/ccsds_ldpc_decoder.qpf` — CCSDS decoder
- `fpga/quartus/ldpc_qc_decoder.qpf` — QC-LDPC decoder

---

## Board Programming

1. Connect DE1-SoC via USB-Blaster
2. Quartus Programmer → Auto Detect → select FPGA row (5CSEMA5F31C6)
3. Change File → select `.sof` from `fpga/quartus/output_files/`
4. Tick Program/Configure → Start

LEDR[1] flashes while decoding. LEDR[2] + LEDR[3] = done + converged (PASS).  
CCSDS LEDR[1] stays on visibly longer (~0.47 ms vs ~68 µs for QC).

---

## Build exe

```bash
pip install pyinstaller
pyinstaller --onefile --windowed --name "Reconciler" ^
    --add-data "matrices;matrices" ^
    --add-data "model;model" ^
    gui/sim_gui.py
```

Output: `dist/Reconciler.exe`

---

## Structure

```
fpga/
  rtl/              SystemVerilog RTL (both decoders + DE1-SoC wrappers)
  tb/               cocotb testbenches + Makefile
  quartus/          Quartus projects, SDC constraints, ROM .mem files
model/
  ldpc/             Python NMSA decoder, channel, LLR, quantisation
  tools/            ROM and matrix generators
  plots/            Plot scripts
gui/
  sim_gui.py        Simulation GUI (Reconciler)
  plot_ber.py       BER/FER waterfall plot
  plot_qkd_results.py  QKD key rate plots
matrices/           LDPC alist files (CCSDS + QC-LDPC irregular)
results/            Simulation outputs and figures
dist/
  Reconciler.exe    Standalone simulation GUI
```

---

## Dependencies

| Tool | Version |
|------|---------|
| Python | 3.12+ |
| PySide6 | latest |
| numpy | latest |
| matplotlib | latest |
| Verilator | 5.036 |
| cocotb | 2.0.1 |
| Quartus Prime Lite | 22.1std.2 |
