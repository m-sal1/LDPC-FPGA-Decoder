// VN adjacency ROM
// Word format: {cn_index[7:0], edge_id[10:0]} packed into 20 bits (bit 19 = 0)
// Address    : vn_edge_base + slot  (maintained by iteration_controller)
// Depth      : NUM_EDGES = 2048  (512 VNs x avg 4 slots)
module vn_rom #(
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

    initial $readmemb("vn_rom.mem", mem);

    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
