// qc_cn_rom.sv
// Address: brow * ROW_WEIGHT + slot  (0..MB*ROW_WEIGHT-1 = 0..95)
// Data:    {col_block[4:0], shift[3:0]}  9 bits
// Author: Mostafa Salman

module qc_cn_rom #(
    parameter int DEPTH = 192,
    parameter int WIDTH = 9
)(
    input  logic clk,
    input  logic [7:0] addr,
    output logic [WIDTH-1:0] data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemb("qc_cn_rom.mem", mem);
    always_ff @(posedge clk) data <= mem[addr];
endmodule
