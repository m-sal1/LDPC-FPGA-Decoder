// qc_vn_rom.sv
// Address: bcol * COL_WEIGHT + slot  (0..NB*COL_WEIGHT-1 = 0..95)
// Data:    {row_block[3:0], shift[3:0]}  8 bits
// Author: Mostafa Salman

module qc_vn_rom #(
    parameter int DEPTH = 192,
    parameter int WIDTH = 8
)(
    input  logic clk,
    input  logic [7:0] addr,
    output logic [WIDTH-1:0] data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemb("qc_vn_rom.mem", mem);
    always_ff @(posedge clk) data <= mem[addr];
endmodule
