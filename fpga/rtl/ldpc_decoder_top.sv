// =============================================================================
// ldpc_decoder_top.sv — Working baseline LDPC decoder (CCSDS n512_k256)
// CN-serial flooding schedule, edge-indexed message banks.
// Verified: TESTS=2 PASS=2, Python<->RTL equivalence confirmed.
// Throughput: 0.53 Mbps at 50MHz (timing closes comfortably).
// Author: Mostafa Salman
// =============================================================================

module ldpc_decoder_top #(
    parameter int WIDTH      = 8,
    parameter int NUM_VN     = 512,
    parameter int NUM_CN     = 256,
    parameter int NUM_EDGES  = 2048,
    parameter int ROW_WEIGHT = 8,
    parameter int MAX_VN_DEG = 5,
    parameter int MAX_ITER   = 50
)(
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic signed [WIDTH-1:0]    llr_in,
    input  logic [$clog2(NUM_VN)-1:0]  llr_write_addr,
    input  logic                       llr_write_enable,

    input  logic                       start,
    output logic                       decoding_done,
    output logic                       converged,

    output logic                       decoded_bit_out,
    output logic [$clog2(NUM_VN)-1:0]  decoded_bit_addr,
    output logic                       decoded_bit_valid
);

    // LLR bank
    logic [$clog2(NUM_VN)-1:0]    llr_rd_addr;
    logic signed [WIDTH-1:0]      llr_rd_data;

    // VC message bank (VN->CN, edge-indexed)
    logic [$clog2(NUM_EDGES)-1:0] vc_wr_addr;
    logic signed [WIDTH-1:0]      vc_wr_data;
    logic                         vc_wr_en;
    logic [$clog2(NUM_EDGES)-1:0] vc_rd_addr;
    logic signed [WIDTH-1:0]      vc_rd_data;

    // CV message bank (CN->VN, edge-indexed)
    logic [$clog2(NUM_EDGES)-1:0] cv_wr_addr;
    logic signed [WIDTH-1:0]      cv_wr_data;
    logic                         cv_wr_en;
    logic [$clog2(NUM_EDGES)-1:0] cv_rd_addr;
    logic signed [WIDTH-1:0]      cv_rd_data;

    // ROMs
    logic [$clog2(NUM_EDGES)-1:0] cn_rom_addr;
    logic [19:0]                  cn_rom_data;
    logic [$clog2(NUM_EDGES)-1:0] vn_rom_addr;
    logic [19:0]                  vn_rom_data;
    logic [$clog2(NUM_VN)-1:0]    deg_rom_addr;
    logic [3:0]                   deg_rom_data;

    // CNU/VNU
    logic                         cnu_valid_in;
    logic                         cnu_valid_out;
    logic signed [WIDTH-1:0]      cnu_msg_in   [ROW_WEIGHT];
    logic signed [WIDTH-1:0]      cnu_msg_out  [ROW_WEIGHT];
    logic signed [WIDTH-1:0]      vnu_msg_in   [MAX_VN_DEG];
    logic signed [WIDTH-1:0]      vnu_llr_in;
    logic [2:0]                   vnu_degree;
    logic signed [WIDTH-1:0]      vnu_extrinsic [MAX_VN_DEG];
    logic signed [WIDTH-1:0]      vnu_belief;

    // Syndrome
    logic                         syn_start, syn_done, syn_pass;

    // Decision bits
    logic [$clog2(NUM_VN)-1:0]    dec_wr_addr;
    logic                         dec_wr_data, dec_wr_en;
    logic [NUM_VN-1:0]            dec_bits_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) dec_bits_reg <= '0;
        else if (dec_wr_en) dec_bits_reg[dec_wr_addr] <= dec_wr_data;
    end

    // Serial readout
    logic [$clog2(NUM_VN)-1:0] readout_addr;
    logic                      readout_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            readout_addr <= '0; readout_active <= 1'b0;
            decoded_bit_out <= 1'b0; decoded_bit_addr <= '0;
            decoded_bit_valid <= 1'b0;
        end else begin
            decoded_bit_valid <= 1'b0;
            if (decoding_done) begin
                readout_addr <= '0; readout_active <= 1'b1;
            end else if (readout_active) begin
                decoded_bit_out   <= dec_bits_reg[readout_addr];
                decoded_bit_addr  <= readout_addr;
                decoded_bit_valid <= 1'b1;
                if (readout_addr == $bits(readout_addr)'(NUM_VN - 1)) begin
                    readout_active <= 1'b0; readout_addr <= '0;
                end else
                    readout_addr <= readout_addr + 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) syn_done <= 1'b0;
        else        syn_done <= syn_start;
    end

    llr_bank #(
        .WIDTH(WIDTH), .NUM_VARIABLES(NUM_VN), .ADDR_WIDTH($clog2(NUM_VN))
    ) llr_bank_inst (
        .clk(clk), .write_enable(llr_write_enable),
        .write_addr(llr_write_addr), .write_data(llr_in),
        .read_enable(1'b1), .read_addr(llr_rd_addr), .read_data(llr_rd_data)
    );

    edge_message_bank #(
        .WIDTH(WIDTH), .NUM_EDGES(NUM_EDGES), .ADDR_WIDTH($clog2(NUM_EDGES))
    ) vc_bank_inst (
        .clk(clk), .read_enable(1'b1),
        .read_addr(vc_rd_addr), .read_data(vc_rd_data),
        .write_enable(vc_wr_en), .write_addr(vc_wr_addr), .write_data(vc_wr_data)
    );

    edge_message_bank #(
        .WIDTH(WIDTH), .NUM_EDGES(NUM_EDGES), .ADDR_WIDTH($clog2(NUM_EDGES))
    ) cv_bank_inst (
        .clk(clk), .read_enable(1'b1),
        .read_addr(cv_rd_addr), .read_data(cv_rd_data),
        .write_enable(cv_wr_en), .write_addr(cv_wr_addr), .write_data(cv_wr_data)
    );

    cn_rom #(
        .DEPTH(NUM_EDGES), .ADDR_WIDTH($clog2(NUM_EDGES)), .WIDTH(20)
    ) cn_rom_inst (
        .clk(clk), .addr(cn_rom_addr), .data(cn_rom_data)
    );

    vn_rom #(
        .DEPTH(NUM_EDGES), .ADDR_WIDTH($clog2(NUM_EDGES)), .WIDTH(20)
    ) vn_rom_inst (
        .clk(clk), .addr(vn_rom_addr), .data(vn_rom_data)
    );

    vn_degree_rom #(
        .DEPTH(NUM_VN), .ADDR_WIDTH($clog2(NUM_VN)), .WIDTH(4)
    ) deg_rom_inst (
        .clk(clk), .addr(deg_rom_addr), .data(deg_rom_data)
    );

    cnu #(.DEGREE(ROW_WEIGHT), .WIDTH(WIDTH)) cnu_inst (
        .clk(clk), .rst(~rst_n),
        .valid_in(cnu_valid_in), .valid_out(cnu_valid_out),
        .msg_in(cnu_msg_in), .msg_out(cnu_msg_out)
    );

    vnu #(.DEGREE(MAX_VN_DEG), .WIDTH(WIDTH)) vnu_inst (
        .llr_in(vnu_llr_in), .msg_in(vnu_msg_in), .degree(vnu_degree),
        .msg_out(vnu_extrinsic), .decision_llr(vnu_belief)
    );

    syndrome_checker syndrome_inst (
        .clk(clk), .decoded_bits(dec_bits_reg), .syndrome_valid(syn_pass)
    );

    iteration_controller #(
        .NUM_VN(NUM_VN), .NUM_CN(NUM_CN), .NUM_EDGES(NUM_EDGES),
        .ROW_WEIGHT(ROW_WEIGHT), .MAX_VN_DEG(MAX_VN_DEG),
        .MSG_WIDTH(WIDTH), .MAX_ITER(MAX_ITER)
    ) ctrl_inst (
        .clk(clk), .rst_n(rst_n), .start(start),
        .done(decoding_done), .converged(converged),
        .llr_rd_addr(llr_rd_addr), .llr_rd_data(llr_rd_data),
        .vc_wr_addr(vc_wr_addr), .vc_wr_data(vc_wr_data), .vc_wr_en(vc_wr_en),
        .vc_rd_addr(vc_rd_addr), .vc_rd_data(vc_rd_data),
        .cv_wr_addr(cv_wr_addr), .cv_wr_data(cv_wr_data), .cv_wr_en(cv_wr_en),
        .cv_rd_addr(cv_rd_addr), .cv_rd_data(cv_rd_data),
        .cn_rom_addr(cn_rom_addr), .cn_rom_data(cn_rom_data),
        .vn_rom_addr(vn_rom_addr), .vn_rom_data(vn_rom_data),
        .deg_rom_addr(deg_rom_addr), .deg_rom_data(deg_rom_data),
        .cnu_valid_in(cnu_valid_in), .cnu_valid_out(cnu_valid_out),
        .cnu_msg_in(cnu_msg_in), .cnu_msg_out(cnu_msg_out),
        .vnu_msg_in(vnu_msg_in), .vnu_llr_in(vnu_llr_in),
        .vnu_degree(vnu_degree), .vnu_extrinsic(vnu_extrinsic),
        .vnu_belief(vnu_belief),
        .syn_pass(syn_pass), .syn_start(syn_start), .syn_done(syn_done),
        .dec_wr_addr(dec_wr_addr), .dec_wr_data(dec_wr_data),
        .dec_wr_en(dec_wr_en)
    );

endmodule
