 // VN adjacency ROM
 // Stores the check-node index and edge ID associated with each VN adjacency slot.
 // Moustafa Salman

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

    // Registered ROM output to match the synchronous memory interface.
    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
