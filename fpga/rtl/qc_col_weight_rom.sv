// qc_col_weight_rom.sv
// Stores the column weight for each QC-LDPC block column.
// Moustafa Salman

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

    // Register the ROM output for synchronous access.
    always_ff @(posedge clk) data <= mem[addr];

endmodule
