// CN adjacency ROM
// Stores the edge ID and variable-node index for each check-node connection.
// Moustafa Salman
//
// Each address corresponds to cn_index * ROW_WEIGHT + slot.

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

    // Register the ROM output to provide a synchronous read interface.
    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
