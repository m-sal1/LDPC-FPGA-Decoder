// qc_vn_cn_slot_rom.sv
// Maps each variable-node slot to its corresponding check-node slot.
// Moustafa Salman

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

    // Register the ROM output for synchronous access.
    always_ff @(posedge clk) data <= mem[addr];

endmodule
