// qc_row_weight_rom.sv
// Stores the row weight for each QC-LDPC block row.
// Moustafa Salman

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

    // Register the ROM output for synchronous access.
    always_ff @(posedge clk) data <= mem[addr];

endmodule
