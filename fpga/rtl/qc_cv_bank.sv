// qc_cv_bank.sv — CN->VN message bank, circulant-ID indexed
//
// Same addressing as qc_vc_bank.
// circ_id = brow*ROW_WEIGHT + cn_slot (0..95)
// Author: Mostafa Salman

module qc_cv_bank #(
    parameter int Z        = 8,
    parameter int DEPTH    = 192,
    parameter int MSG_WIDTH = 8
)(
    input  logic clk,

    input  logic [$clog2(DEPTH)-1:0]    rd_addr,
    input  logic                         rd_en,
    output logic signed [MSG_WIDTH-1:0] rd_data [0:Z-1],

    input  logic [$clog2(DEPTH)-1:0]    wr_addr,
    input  logic                         wr_en,
    input  logic signed [MSG_WIDTH-1:0] wr_data [0:Z-1]
);
    logic [Z*MSG_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr_en) begin
            for (int k = 0; k < Z; k++)
                mem[wr_addr][k*MSG_WIDTH +: MSG_WIDTH] <= wr_data[k];
        end
        if (rd_en) begin
            for (int k = 0; k < Z; k++)
                rd_data[k] <= $signed(mem[rd_addr][k*MSG_WIDTH +: MSG_WIDTH]);
        end
    end
endmodule
