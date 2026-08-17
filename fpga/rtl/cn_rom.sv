// CN adjacency ROM
// Word format: {edge_id[10:0], vn_index[8:0]} packed into 20 bits
// Address    : cn_index * ROW_WEIGHT + slot
// Depth      : NUM_EDGES = 2048  (256 CNs x 8 slots)
module cn_rom #(
    parameter int DEPTH      = 2048,
    parameter int ADDR_WIDTH = 11,
    parameter int WIDTH      = 20
)(
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [WIDTH-1:0]      data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    initial $readmemb("cn_rom.mem", mem);

    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
