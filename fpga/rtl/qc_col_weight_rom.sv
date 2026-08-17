// qc_col_weight_rom.sv
// Depth: NB=64, Width: 2 bits
// Data: actual col weight for each block-col (2 or 3)
// Author: Mostafa Salman

module qc_col_weight_rom #(
    parameter int DEPTH = 64,
    parameter int WIDTH = 2
)(
    input  logic clk,
    input  logic [5:0] addr,
    output logic [WIDTH-1:0] data
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemb("qc_col_weight.mem", mem);
    always_ff @(posedge clk) data <= mem[addr];
endmodule