// qc_ldpc_decoder_top.sv
// Top-level QC-LDPC decoder integrating the memory banks, lookup ROMs, parallel CNU/VNU units, and iteration controller.
// Moustafa Salman

module qc_ldpc_decoder_top #(
    parameter int MSG_WIDTH  = 8,
    parameter int Z          = 8,
    parameter int MB         = 32,
    parameter int NB         = 64,
    parameter int MAX_ROW_W  = 6,
    parameter int MAX_COL_W  = 3,
    parameter int NUM_VN     = 512,
    parameter int NUM_CN     = 256,
    parameter int MAX_ITER   = 50
)(
    input  logic                        clk,
    input  logic                        rst_n,

    input  logic signed [MSG_WIDTH-1:0] llr_in,
    input  logic [$clog2(NUM_VN)-1:0]  llr_write_addr,
    input  logic                        llr_write_enable,

    input  logic                        start,
    output logic                        decoding_done,
    output logic                        converged,

    output logic                        decoded_bit_out,
    output logic [$clog2(NUM_VN)-1:0]  decoded_bit_addr,
    output logic                        decoded_bit_valid
);

    // LLR memory is organised by base-column, with Z values read in parallel.
    logic [$clog2(NB)-1:0]       llr_rd_bcol;
    logic signed [MSG_WIDTH-1:0] llr_rd_data [0:Z-1];

    qc_llr_bank #(.Z(Z),.NB(NB),.MSG_WIDTH(MSG_WIDTH)) llr_bank_inst (
        .clk(clk),
        .wr_addr(llr_write_addr), .wr_data(llr_in), .wr_en(llr_write_enable),
        .rd_bcol(llr_rd_bcol),    .rd_data(llr_rd_data)
    );

    // Message banks store one Z-wide group for each circulant position.
    // The depth is padded to accommodate the maximum row weight.
    localparam int CIRC_DEPTH = MB * MAX_ROW_W;

    logic [7:0]                  vc_rd_addr, vc_wr_addr;
    logic                        vc_rd_en,   vc_wr_en;
    logic signed [MSG_WIDTH-1:0] vc_rd_data [0:Z-1];
    logic signed [MSG_WIDTH-1:0] vc_wr_data [0:Z-1];

    logic [7:0]                  cv_rd_addr, cv_wr_addr;
    logic                        cv_rd_en,   cv_wr_en;
    logic signed [MSG_WIDTH-1:0] cv_rd_data [0:Z-1];
    logic signed [MSG_WIDTH-1:0] cv_wr_data [0:Z-1];

    qc_vc_bank #(.Z(Z),.DEPTH(CIRC_DEPTH),.MSG_WIDTH(MSG_WIDTH)) vc_bank_inst (
        .clk(clk),
        .rd_addr(vc_rd_addr), .rd_en(vc_rd_en), .rd_data(vc_rd_data),
        .wr_addr(vc_wr_addr), .wr_en(vc_wr_en), .wr_data(vc_wr_data)
    );

    qc_cv_bank #(.Z(Z),.DEPTH(CIRC_DEPTH),.MSG_WIDTH(MSG_WIDTH)) cv_bank_inst (
        .clk(clk),
        .rd_addr(cv_rd_addr), .rd_en(cv_rd_en), .rd_data(cv_rd_data),
        .wr_addr(cv_wr_addr), .wr_en(cv_wr_en), .wr_data(cv_wr_data)
    );

    // ROMs provide the QC connectivity and the variable-node slot mapping.
    logic [7:0] cn_rom_addr;
    logic [8:0] cn_rom_data;
    logic [7:0] vn_rom_addr;
    logic [7:0] vn_rom_data;
    logic [7:0] vn_cn_slot_addr;
    logic [2:0] vn_cn_slot_data;

    qc_cn_rom cn_rom_inst (
        .clk(clk), .addr(cn_rom_addr), .data(cn_rom_data));
    qc_vn_rom vn_rom_inst (
        .clk(clk), .addr(vn_rom_addr), .data(vn_rom_data));
    qc_vn_cn_slot_rom vn_cn_slot_rom_inst (
        .clk(clk), .addr(vn_cn_slot_addr), .data(vn_cn_slot_data));

    // Rotates the Z values according to the circulant shift required by
    // the current QC-LDPC connection.
    logic signed [MSG_WIDTH-1:0] shift_in  [0:Z-1];
    logic [$clog2(Z)-1:0]        shift_amt;
    logic signed [MSG_WIDTH-1:0] shift_out [0:Z-1];

    barrel_shifter #(.Z(Z),.MSG_WIDTH(MSG_WIDTH)) shifter_inst (
        .data_in(shift_in), .shift(shift_amt), .data_out(shift_out));

    // Eight CNU instances process the Z rows in parallel. Each CNU uses
    // a four-stage pipeline to reduce the combinational critical path.
    logic                        cnu_valid_in, cnu_valid_out;
    logic signed [MSG_WIDTH-1:0] cnu_msg_in  [0:Z-1][0:MAX_ROW_W-1];
    logic signed [MSG_WIDTH-1:0] cnu_msg_out [0:Z-1][0:MAX_ROW_W-1];

    genvar gz;
    generate
        for (gz = 0; gz < Z; gz++) begin : cnu_array
            logic signed [MSG_WIDTH-1:0] cnu_in_flat  [0:MAX_ROW_W-1];
            logic signed [MSG_WIDTH-1:0] cnu_out_flat [0:MAX_ROW_W-1];
            always_comb begin
                for (int s = 0; s < MAX_ROW_W; s++) begin
                    cnu_in_flat[s]     = cnu_msg_in[gz][s];
                    cnu_msg_out[gz][s] = cnu_out_flat[s];
                end
            end
            cnu #(.DEGREE(MAX_ROW_W),.WIDTH(MSG_WIDTH)) cnu_inst (
                .clk(clk), .rst(~rst_n),
                .valid_in(cnu_valid_in), .valid_out(cnu_valid_out),
                .msg_in(cnu_in_flat),    .msg_out(cnu_out_flat));
        end
    endgenerate

    // Eight VNU instances process the Z variable nodes in parallel.
    logic signed [MSG_WIDTH-1:0] vnu_msg_in    [0:Z-1][0:MAX_COL_W-1];
    logic signed [MSG_WIDTH-1:0] vnu_llr_in    [0:Z-1];
    logic [2:0]                  vnu_degree;
    logic signed [MSG_WIDTH-1:0] vnu_extrinsic [0:Z-1][0:MAX_COL_W-1];
    logic signed [MSG_WIDTH-1:0] vnu_belief    [0:Z-1];

    generate
        for (gz = 0; gz < Z; gz++) begin : vnu_array
            logic signed [MSG_WIDTH-1:0] vnu_in_flat  [0:MAX_COL_W-1];
            logic signed [MSG_WIDTH-1:0] vnu_out_flat [0:MAX_COL_W-1];
            always_comb begin
                for (int s = 0; s < MAX_COL_W; s++) begin
                    vnu_in_flat[s]       = vnu_msg_in[gz][s];
                    vnu_extrinsic[gz][s] = vnu_out_flat[s];
                end
            end
            vnu #(.DEGREE(MAX_COL_W),.WIDTH(MSG_WIDTH)) vnu_inst (
                .llr_in(vnu_llr_in[gz]),
                .msg_in(vnu_in_flat),
                .degree(vnu_degree),
                .msg_out(vnu_out_flat),
                .decision_llr(vnu_belief[gz]));
        end
    endgenerate

    // Stores the hard decisions produced for each group of Z variable nodes.
    logic [$clog2(NB)-1:0] dec_wr_bcol;
    logic [Z-1:0]           dec_wr_data;
    logic                   dec_wr_en;
    logic [NUM_VN-1:0]      dec_bits_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) dec_bits_reg <= '0;
        else if (dec_wr_en) begin
            for (int k = 0; k < Z; k++)
                dec_bits_reg[dec_wr_bcol * Z + k] <= dec_wr_data[k];
        end
    end

    // Checks the stored hard decisions against the parity-check equations.
    logic syn_pass, syn_start, syn_done;

    syndrome_checker syndrome_inst (
        .clk(clk),
        .decoded_bits(dec_bits_reg),
        .syndrome_valid(syn_pass)
    );

    // Register the syndrome request so the controller can wait for a
    // defined clock boundary before evaluating the result.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) syn_done <= 1'b0;
        else        syn_done <= syn_start;
    end

    // Serialise the completed decoded codeword through the top-level output.
    logic [$clog2(NUM_VN)-1:0] readout_addr;
    logic                       readout_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            readout_addr      <= '0;
            readout_active    <= 1'b0;
            decoded_bit_out   <= 1'b0;
            decoded_bit_addr  <= '0;
            decoded_bit_valid <= 1'b0;
        end else begin
            decoded_bit_valid <= 1'b0;
            if (decoding_done) begin
                readout_addr   <= '0;
                readout_active <= 1'b1;
            end else if (readout_active) begin
                decoded_bit_out   <= dec_bits_reg[readout_addr];
                decoded_bit_addr  <= readout_addr;
                decoded_bit_valid <= 1'b1;
                if (readout_addr == $bits(readout_addr)'(NUM_VN - 1)) begin
                    readout_active <= 1'b0;
                    readout_addr   <= '0;
                end else
                    readout_addr <= readout_addr + 1'b1;
            end
        end
    end

    // ROMs containing the row and column weights used by the controller.
    logic [4:0] row_w_addr;
    logic [2:0] row_w_data;
    logic [5:0] col_w_addr;
    logic [1:0] col_w_data;

    qc_row_weight_rom row_w_rom_inst (
        .clk(clk), .addr(row_w_addr), .data(row_w_data));
    qc_col_weight_rom col_w_rom_inst (
        .clk(clk), .addr(col_w_addr), .data(col_w_data));

    // Coordinates the QC-LDPC message-passing schedule, memory accesses,
    // node updates, syndrome checks, and iteration control.
    qc_iteration_controller #(
        .Z         (Z),
        .MB        (MB),
        .NB        (NB),
        .MAX_ROW_W (MAX_ROW_W),
        .MAX_COL_W (MAX_COL_W),
        .CIRC_DEPTH(CIRC_DEPTH),
        .MSG_WIDTH (MSG_WIDTH),
        .MAX_ITER  (MAX_ITER)
    ) ctrl_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .done         (decoding_done),
        .converged    (converged),
        .llr_rd_bcol  (llr_rd_bcol),
        .llr_rd_data  (llr_rd_data),
        .vc_rd_addr   (vc_rd_addr),   .vc_rd_en(vc_rd_en), .vc_rd_data(vc_rd_data),
        .vc_wr_addr   (vc_wr_addr),   .vc_wr_en(vc_wr_en), .vc_wr_data(vc_wr_data),
        .cv_rd_addr   (cv_rd_addr),   .cv_rd_en(cv_rd_en), .cv_rd_data(cv_rd_data),
        .cv_wr_addr   (cv_wr_addr),   .cv_wr_en(cv_wr_en), .cv_wr_data(cv_wr_data),
        .cn_rom_addr  (cn_rom_addr),  .cn_rom_data(cn_rom_data),
        .vn_rom_addr  (vn_rom_addr),  .vn_rom_data(vn_rom_data),
        .vn_cn_slot_addr(vn_cn_slot_addr), .vn_cn_slot_data(vn_cn_slot_data),
        .row_w_addr   (row_w_addr),   .row_w_data(row_w_data),
        .col_w_addr   (col_w_addr),   .col_w_data(col_w_data),
        .shift_in     (shift_in),     .shift_amt(shift_amt), .shift_out(shift_out),
        .cnu_valid_in (cnu_valid_in), .cnu_valid_out(cnu_valid_out),
        .cnu_msg_in   (cnu_msg_in),   .cnu_msg_out(cnu_msg_out),
        .vnu_msg_in   (vnu_msg_in),   .vnu_llr_in(vnu_llr_in),
        .vnu_degree   (vnu_degree),
        .vnu_extrinsic(vnu_extrinsic),.vnu_belief(vnu_belief),
        .syn_pass     (syn_pass),     .syn_start(syn_start), .syn_done(syn_done),
        .dec_wr_bcol  (dec_wr_bcol),  .dec_wr_data(dec_wr_data), .dec_wr_en(dec_wr_en)
    );

endmodule
