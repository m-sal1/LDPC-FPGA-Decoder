// qc_vn_rom.sv
// Stores the QC-LDPC variable-node connectivity and circulant shift values.
// Moustafa Salman

module qc_vn_rom #(
    parameter int DEPTH = 192,
    parameter int WIDTH = 8
)(
    input  logic clk,
    input logic [7:0] addr,
    output logic [WIDTH-1:0] data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];

    initial $readmemb("qc_vn_rom.mem", mem);

    // Register the ROM output for synchronous access.
    always_ff @(posedge clk) data <= mem[addr];

endmodule
