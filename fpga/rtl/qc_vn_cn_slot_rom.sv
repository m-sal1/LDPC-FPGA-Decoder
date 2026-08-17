// qc_vn_cn_slot_rom.sv
// Maps (bcol, vn_slot) -> cn_slot for vc_bank write address in VN phase.
// circ_id = brow*ROW_WEIGHT + cn_slot
// Address: bcol*COL_WEIGHT + vn_slot  (0..NB*COL_WEIGHT-1 = 0..95)
// Data:    cn_slot[2:0]  (3 bits, max value ROW_WEIGHT-1=5)
// Author: Mostafa Salman

module qc_vn_cn_slot_rom #(
    parameter int DEPTH = 192,
    parameter int WIDTH = 3
)(
    input  logic clk,
    input  logic [7:0] addr,
    output logic [WIDTH-1:0] data
);
    (* ramstyle = "M10K" *)
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    initial $readmemb("qc_vn_cn_slot.mem", mem);
    always_ff @(posedge clk) data <= mem[addr];
endmodule
