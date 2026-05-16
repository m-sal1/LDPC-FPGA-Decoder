from pathlib import Path


ALIST_FILE = Path("../../matrices/CCSDS_ldpc_n512_k256.alist")

OUTPUT_FILE = Path("../../fpga/rtl/check_node_map.mem")


def parse_alist(path):

    with open(path, "r") as f:
        lines = [line.strip() for line in f.readlines()]

    n_cols, n_rows = map(int, lines[0].split())

    max_col_weight, max_row_weight = map(int, lines[1].split())

    col_weights = list(map(int, lines[2].split()))

    row_weights = list(map(int, lines[3].split()))

    row_start = 4 + n_cols

    check_node_connections = []

    for cn in range(n_rows):

        vn_entries = list(
            map(int, lines[row_start + cn].split())
        )

        connected_vns = []

        for vn in vn_entries[:row_weights[cn]]:

            if vn == 0:
                continue

            connected_vns.append(vn - 1)

        check_node_connections.append(connected_vns)

    return check_node_connections


def write_check_node_map(check_map, output_path):

    with open(output_path, "w") as f:

        for row in check_map:

            packed_row = ""

            for vn in row:

                packed_row += f"{vn:010b}"

            f.write(packed_row + "\n")


def main():

    check_map = parse_alist(ALIST_FILE)

    write_check_node_map(check_map, OUTPUT_FILE)

    print("===================================")
    print("CHECK NODE MAP GENERATED")
    print("===================================")

    print(f"Check nodes: {len(check_map)}")

    print(f"Output file: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
