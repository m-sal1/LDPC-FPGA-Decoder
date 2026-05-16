from pathlib import Path


ALIST_FILE = Path("../../matrices/CCSDS_ldpc_n512_k256.alist")

OUTPUT_FILE = Path("../../fpga/rtl/edge_map.mem")


def parse_alist(path):

    with open(path, "r") as f:
        lines = [line.strip() for line in f.readlines()]

    n_cols, n_rows = map(int, lines[0].split())

    max_col_weight, max_row_weight = map(int, lines[1].split())

    col_weights = list(map(int, lines[2].split()))

    row_weights = list(map(int, lines[3].split()))

    col_start = 4

    vn_to_cn = []

    edge_index = 0

    for vn in range(n_cols):

        row_entries = list(
            map(int, lines[col_start + vn].split())
        )

        for cn in row_entries[:col_weights[vn]]:

            if cn == 0:
                continue

            vn_to_cn.append((edge_index, vn, cn - 1))

            edge_index += 1

    return vn_to_cn


def write_edge_map(edge_list, output_path):

    with open(output_path, "w") as f:

        for edge_id, vn, cn in edge_list:

            # Pack:
            # upper 10 bits = VN index
            # lower 10 bits = CN index

            packed = (vn << 10) | cn

            f.write(f"{packed:020b}\n")


def main():

    edge_map = parse_alist(ALIST_FILE)

    write_edge_map(edge_map, OUTPUT_FILE)

    print("===================================")
    print("EDGE MAP GENERATION COMPLETE")
    print("===================================")

    print(f"Total edges: {len(edge_map)}")

    print(f"Output file: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
