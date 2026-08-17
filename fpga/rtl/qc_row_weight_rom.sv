// qc_row_weight_rom.sv
// Depth: MB=32, Width: 3 bits
// Data: actual row weight for each block-row (5 or 6)
// Author: Mostafa Salman

module qc_row_weight_rom #(
    parameter int DEPTH = 32,
    parameter int WIDTH = 3
)(
    input  logic clk,
    input  logic [4:0] addr,
    output logic [WIDTH-1:0] data
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemb("qc_row_weight.mem", mem);
    always_ff @(posedge clk) data <= mem[addr];
endmodule
