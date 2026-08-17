// qc_llr_bank.sv
// Stores and reads channel LLRs for the QC-LDPC decoder.
// Moustafa Salman

module qc_llr_bank #(
    parameter int Z         = 8,
    parameter int NB        = 64,
    parameter int MSG_WIDTH = 8
)(
    input  logic clk,

    // External interface writes one LLR at a time.
    input  logic [$clog2(NB*Z)-1:0]      wr_addr,
    input  logic signed [MSG_WIDTH-1:0]  wr_data,
    input  logic                          wr_en,

    // Decoder interface reads all Z LLRs belonging to one block column.
    input  logic [$clog2(NB)-1:0]        rd_bcol,
    output logic signed [MSG_WIDTH-1:0]  rd_data [0:Z-1]
);
    localparam WIDTH = Z * MSG_WIDTH;

    logic [WIDTH-1:0] mem [0:NB-1];

    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr[$clog2(NB*Z)-1:$clog2(Z)]]
               [wr_addr[$clog2(Z)-1:0]*MSG_WIDTH +: MSG_WIDTH] <= wr_data;
        end

        // Read the complete block column into the output registers.
        for (int k = 0; k < Z; k++)
            rd_data[k] <= $signed(mem[rd_bcol][k*MSG_WIDTH +: MSG_WIDTH]);
    end

endmodule
