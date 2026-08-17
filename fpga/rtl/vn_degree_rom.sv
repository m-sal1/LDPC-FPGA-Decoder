 // VN degree ROM
 // Stores the actual column weight for each variable node.
 // Moustafa Salman

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

    // Register the ROM output to provide a synchronous read interface.
    always_ff @(posedge clk)
        data <= mem[addr];

endmodule
