"""
generate_cn_rom.py

Generates cn_rom.mem for the CN-serial LDPC decoder.

For each check node CN_i and each of its edge slots, outputs one ROM word:
    [19:9]  edge_id   (11 bits)
    [8:0]   vn_index  ( 9 bits)

ROM address = cn_index * row_weight + slot

All weights are read directly from the alist file — nothing is hardcoded.

Usage (from project root):
    python -m model.tools.generate_cn_rom
"""

from pathlib import Path

_HERE       = Path(__file__).resolve().parent
ALIST_FILE  = _HERE.parent.parent / "matrices" / "CCSDS_ldpc_n512_k256.alist"
OUTPUT_FILE = _HERE.parent.parent / "fpga" / "rtl" / "cn_rom.mem"


# ── parser ──────────────────────────────────────────────────────────────────

def parse_alist(path):
    """
    Returns:
        n_cols      : number of variable nodes
        n_rows      : number of check nodes
        col_weights : per-VN degree list
        row_weights : per-CN degree list
        col_entries : col_entries[vn] = list of CN indices (0-based)
        row_entries : row_entries[cn] = list of VN indices (0-based)
    """
    with open(path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    n_cols, n_rows         = map(int, lines[0].split())
    col_weights            = list(map(int, lines[2].split()))
    row_weights            = list(map(int, lines[3].split()))

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


# ── edge ID map ─────────────────────────────────────────────────────────────

def build_edge_id_map(n_cols, col_weights, col_entries):
    """
    Assigns edge IDs in VN-first order (matching generate_edge_map.py):
        edge_id = sum(col_weights[0..vn-1]) + local_slot
    For a regular code (all col_weights equal) this simplifies to
        edge_id = vn * col_weight + slot
    This version handles irregular codes too.
    """
    edge_map = {}
    edge_id = 0
    for vn in range(n_cols):
        for slot, cn in enumerate(col_entries[vn]):
            edge_map[(vn, cn)] = edge_id
            edge_id += 1
    return edge_map


# ── ROM generation ──────────────────────────────────────────────────────────

def generate_cn_rom(n_rows, row_weights, row_entries, edge_map):
    """
    ROM[cn * row_weight + slot] = {edge_id[10:0], vn_index[8:0]} packed to 20 bits.
    Raises if any CN has a degree different from row_weights[cn].
    """
    rom = []
    for cn in range(n_rows):
        vns = row_entries[cn]
        if len(vns) != row_weights[cn]:
            raise ValueError(
                f"CN {cn}: got {len(vns)} neighbours, "
                f"expected {row_weights[cn]} from weight list"
            )
        for vn in vns:
            edge_id = edge_map[(vn, cn)]
            word = (edge_id << 9) | vn
            rom.append(word)
    return rom


# ── writer ──────────────────────────────────────────────────────────────────

def write_mem(rom, output_path, word_bits=20):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        for word in rom:
            f.write(f"{word:0{word_bits}b}\n")


# ── self-check ──────────────────────────────────────────────────────────────

def verify(n_cols, n_rows, col_weights, row_weights,
           col_entries, row_entries, edge_map, rom):

    total_edges = sum(col_weights)
    assert len(rom) == total_edges, \
        f"ROM length {len(rom)} != total edges {total_edges}"

    # Decode every ROM word and cross-check against row_entries
    addr = 0
    for cn in range(n_rows):
        for slot in range(row_weights[cn]):
            word     = rom[addr]
            edge_id  = (word >> 9) & 0x7FF
            vn_index =  word       & 0x1FF
            assert vn_index == row_entries[cn][slot], \
                f"CN{cn} slot{slot}: VN {vn_index} != expected {row_entries[cn][slot]}"
            assert edge_id == edge_map[(vn_index, cn)], \
                f"CN{cn} slot{slot}: edge_id {edge_id} != expected {edge_map[(vn_index, cn)]}"
            addr += 1

    # Every edge ID must appear exactly once
    all_eids = sorted([(rom[i] >> 9) & 0x7FF for i in range(len(rom))])
    assert all_eids == list(range(total_edges)), \
        "Edge IDs are not a complete permutation of 0..total_edges-1"

    print("Self-check PASSED")


# ── main ────────────────────────────────────────────────────────────────────

def main():
    print(f"Parsing {ALIST_FILE} ...")
    n_cols, n_rows, col_weights, row_weights, col_entries, row_entries = \
        parse_alist(ALIST_FILE)

    total_edges  = sum(col_weights)
    max_col_w    = max(col_weights)
    max_row_w    = max(row_weights)
    min_col_w    = min(col_weights)
    min_row_w    = min(row_weights)

    print(f"  Variable nodes : {n_cols}")
    print(f"  Check nodes    : {n_rows}")
    print(f"  Col weight     : {min_col_w}..{max_col_w}  "
          f"({'regular' if min_col_w == max_col_w else 'IRREGULAR'})")
    print(f"  Row weight     : {min_row_w}..{max_row_w}  "
          f"({'regular' if min_row_w == max_row_w else 'IRREGULAR'})")
    print(f"  Total edges    : {total_edges}")

    print("Building edge ID map ...")
    edge_map = build_edge_id_map(n_cols, col_weights, col_entries)

    print("Generating CN ROM ...")
    rom = generate_cn_rom(n_rows, row_weights, row_entries, edge_map)

    print("Running self-check ...")
    verify(n_cols, n_rows, col_weights, row_weights,
           col_entries, row_entries, edge_map, rom)

    print(f"Writing {OUTPUT_FILE} ...")
    write_mem(rom, OUTPUT_FILE)

    print()
    print("=" * 42)
    print("CN ROM GENERATION COMPLETE")
    print("=" * 42)
    print(f"  ROM words      : {len(rom)}")
    print(f"  Word format    : edge_id[10:0] | vn_index[8:0]  (20 bits)")
    print(f"  Output         : {OUTPUT_FILE}")
    print()
    print("SystemVerilog parameters to use:")
    print(f"  NUM_VN         = {n_cols}")
    print(f"  NUM_CN         = {n_rows}")
    print(f"  NUM_EDGES      = {total_edges}")
    print(f"  ROW_WEIGHT     = {max_row_w}   <- use in CNU and FSM")
    print(f"  COL_WEIGHT     = {max_col_w}   <- use in VNU and FSM")
    print(f"  CN_ROM_DEPTH   = {len(rom)}")


if __name__ == "__main__":
    main()
