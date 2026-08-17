// VN degree ROM — actual column weight of each variable node (3, 4, or 5)
// Address : vn_index  (0..511)
// Depth   : NUM_VN = 512
module vn_degree_rom #(
    parameter int DEPTH      = 512,
    parameter int ADDR_WIDTH = 9,
    parameter int WIDTH      = 4
)(
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [WIDTH-1:0]      data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    initial $readmemb("vn_degree_rom.mem", mem);

    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
