"""
generate_vn_rom.py

Generates two ROM files for the VN phase of the CN-serial LDPC decoder:

1. vn_rom.mem
   ROM address = cumulative edge offset for VN j + slot
   Each word (20 bits):
       [18:11]  cn_index  (8 bits)
       [10:0]   edge_id   (11 bits)
       [19]     always 0

2. vn_degree_rom.mem
   ROM address = vn_index  (0..511)
   Each word (3 bits, zero-padded to 4):
       actual column weight of VN j  (3, 4, or 5 for CCSDS n512_k256)

Both files are needed by iteration_controller.sv because the code is
IRREGULAR (column weights vary between VNs).

Usage (from project root):
    python -m model.tools.generate_vn_rom
"""

from pathlib import Path

_HERE            = Path(__file__).resolve().parent
ALIST_FILE       = _HERE.parent.parent / "matrices" / "CCSDS_ldpc_n512_k256.alist"
OUTPUT_VN_ROM    = _HERE.parent.parent / "fpga" / "rtl" / "vn_rom.mem"
OUTPUT_DEG_ROM   = _HERE.parent.parent / "fpga" / "rtl" / "vn_degree_rom.mem"


# ── parser ──────────────────────────────────────────────────────────────────

def parse_alist(path):
    with open(path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    n_cols, n_rows  = map(int, lines[0].split())
    col_weights     = list(map(int, lines[2].split()))
    row_weights     = list(map(int, lines[3].split()))

    col_entries = []
    for vn in range(n_cols):
        raw = list(map(int, lines[4 + vn].split()))
        cns = [x - 1 for x in raw[:col_weights[vn]] if x != 0]
        col_entries.append(cns)

    row_start = 4 + n_cols
    row_entries = []
    for cn in range(n_rows):
        raw = list(map(int, lines[row_start + cn].split()))
        vns = [x - 1 for x in raw[:row_weights[cn]] if x != 0]
        row_entries.append(vns)

    return n_cols, n_rows, col_weights, row_weights, col_entries, row_entries


# ── VN ROM generation ────────────────────────────────────────────────────────

def generate_vn_rom(n_cols, col_weights, col_entries):
    """
    Iterates VN-first (matching generate_edge_map.py and generate_cn_rom.py).
    Edge IDs are assigned sequentially as we walk VN 0..511, slot 0..degree-1.
    Returns a flat list of 20-bit integers, one per edge (total = NUM_EDGES).
    """
    rom = []
    edge_id = 0
    for vn in range(n_cols):
        if len(col_entries[vn]) != col_weights[vn]:
            raise ValueError(
                f"VN {vn}: got {len(col_entries[vn])} neighbours, "
                f"expected {col_weights[vn]}"
            )
        for cn in col_entries[vn]:
            word = (cn << 11) | edge_id
            rom.append(word)
            edge_id += 1
    return rom


# ── Degree ROM generation ────────────────────────────────────────────────────

def generate_degree_rom(n_cols, col_weights):
    """
    Returns a list of n_cols integers, one per VN.
    Value = actual column weight of that VN (3, 4, or 5).
    """
    return list(col_weights)


# ── writers ──────────────────────────────────────────────────────────────────

def write_mem(rom, output_path, word_bits):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for word in rom:
            f.write(f"{word:0{word_bits}b}\n")


# ── self-checks ──────────────────────────────────────────────────────────────

def verify_vn_rom(n_cols, n_rows, col_weights, row_weights,
                  col_entries, row_entries, rom):

    total_edges = sum(col_weights)
    assert len(rom) == total_edges, \
        f"VN ROM length {len(rom)} != total edges {total_edges}"

    # Decode every word and check against col_entries
    addr = 0
    for vn in range(n_cols):
        for slot in range(col_weights[vn]):
            word     = rom[addr]
            cn_index = (word >> 11) & 0xFF
            edge_id  =  word        & 0x7FF
            assert cn_index == col_entries[vn][slot], \
                f"VN{vn} slot{slot}: CN {cn_index} != expected {col_entries[vn][slot]}"
            assert edge_id == addr, \
                f"VN{vn} slot{slot}: edge_id {edge_id} != expected {addr}"
            addr += 1

    # Every edge ID must appear exactly once
    all_eids = sorted([rom[i] & 0x7FF for i in range(len(rom))])
    assert all_eids == list(range(total_edges)), \
        "Edge IDs not a complete permutation of 0..total_edges-1"

    # Cross-check: every CN claimed by a VN must list that VN back
    addr = 0
    for vn in range(n_cols):
        for slot in range(col_weights[vn]):
            cn = (rom[addr] >> 11) & 0xFF
            assert vn in row_entries[cn], \
                f"VN{vn} claims CN{cn} but CN{cn} doesn't list VN{vn}"
            addr += 1

    print("VN ROM self-check PASSED")


def verify_degree_rom(n_cols, col_weights, degree_rom):
    assert len(degree_rom) == n_cols, \
        f"Degree ROM length {len(degree_rom)} != NUM_VN {n_cols}"
    for vn in range(n_cols):
        assert degree_rom[vn] == col_weights[vn], \
            f"VN{vn}: degree_rom={degree_rom[vn]} != col_weights={col_weights[vn]}"
    print("Degree ROM self-check PASSED")


# ── main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"Parsing {ALIST_FILE} ...")
    n_cols, n_rows, col_weights, row_weights, col_entries, row_entries = \
        parse_alist(ALIST_FILE)

    total_edges = sum(col_weights)
    max_col_w   = max(col_weights)
    min_col_w   = min(col_weights)
    max_row_w   = max(row_weights)
    min_row_w   = min(row_weights)

    print(f"  Variable nodes : {n_cols}")
    print(f"  Check nodes    : {n_rows}")
    print(f"  Col weight     : {min_col_w}..{max_col_w}  "
          f"({'regular' if min_col_w == max_col_w else 'IRREGULAR'})")
    print(f"  Row weight     : {min_row_w}..{max_row_w}  "
          f"({'regular' if min_row_w == max_row_w else 'IRREGULAR'})")
    print(f"  Total edges    : {total_edges}")

    # ── VN ROM ───────────────────────────────────────────────────────────────
    print("\nGenerating VN ROM ...")
    vn_rom = generate_vn_rom(n_cols, col_weights, col_entries)

    print("Running VN ROM self-check ...")
    verify_vn_rom(n_cols, n_rows, col_weights, row_weights,
                  col_entries, row_entries, vn_rom)

    print(f"Writing {OUTPUT_VN_ROM} ...")
    write_mem(vn_rom, OUTPUT_VN_ROM, word_bits=20)

    # ── Degree ROM ────────────────────────────────────────────────────────────
    print("\nGenerating VN degree ROM ...")
    degree_rom = generate_degree_rom(n_cols, col_weights)

    print("Running degree ROM self-check ...")
    verify_degree_rom(n_cols, col_weights, degree_rom)

    print(f"Writing {OUTPUT_DEG_ROM} ...")
    # 3 bits is enough for values 3..5, but use 4 for byte alignment in SV
    write_mem(degree_rom, OUTPUT_DEG_ROM, word_bits=4)

    # ── Summary ───────────────────────────────────────────────────────────────
    print()
    print("=" * 42)
    print("VN ROM + DEGREE ROM GENERATION COMPLETE")
    print("=" * 42)
    print(f"  vn_rom words      : {len(vn_rom)}")
    print(f"  vn_rom format     : cn_index[7:0] | edge_id[10:0]  (20 bits)")
    print(f"  degree_rom words  : {len(degree_rom)}")
    print(f"  degree_rom format : vn_degree[3:0]  (values {min_col_w}..{max_col_w})")
    print()
    print("SystemVerilog parameters to use:")
    print(f"  NUM_VN            = {n_cols}")
    print(f"  NUM_CN            = {n_rows}")
    print(f"  NUM_EDGES         = {total_edges}")
    print(f"  ROW_WEIGHT        = {max_row_w}   // regular - CNU port width")
    print(f"  MAX_VN_DEG        = {max_col_w}   // max col weight - VNU port width")
    print(f"  MIN_VN_DEG        = {min_col_w}   // for reference")


if __name__ == "__main__":
    main()
