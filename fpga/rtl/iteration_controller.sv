// iteration_controller.sv
// Controls the CN-serial flooding schedule and coordinates each LDPC decoding iteration.
// Handles the irregular variable-node degrees used by the CCSDS n512_k256 code.
// Moustafa Salman

module iteration_controller #(
    parameter int NUM_VN     = 512,
    parameter int NUM_CN     = 256,
    parameter int NUM_EDGES  = 2048,
    parameter int ROW_WEIGHT = 8,
    parameter int MAX_VN_DEG = 5,
    parameter int MSG_WIDTH  = 8,
    parameter int MAX_ITER   = 50
)(
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    output logic done,
    output logic converged,

    // LLR bank
    output logic [$clog2(NUM_VN)-1:0]    llr_rd_addr,
    input  logic signed [MSG_WIDTH-1:0]  llr_rd_data,

    // VN-to-CN message bank
    output logic [$clog2(NUM_EDGES)-1:0] vc_wr_addr,
    output logic signed [MSG_WIDTH-1:0] vc_wr_data,
    output logic                         vc_wr_en,
    output logic [$clog2(NUM_EDGES)-1:0] vc_rd_addr,
    input  logic signed [MSG_WIDTH-1:0]  vc_rd_data,

    // CN-to-VN message bank
    output logic [$clog2(NUM_EDGES)-1:0] cv_wr_addr,
    output logic signed [MSG_WIDTH-1:0] cv_wr_data,
    output logic                         cv_wr_en,
    output logic [$clog2(NUM_EDGES)-1:0] cv_rd_addr,
    input  logic signed [MSG_WIDTH-1:0]  cv_rd_data,

    // cn_rom: {edge_id[10:0], vn_index[8:0]} packed 20 bits
    output logic [$clog2(NUM_EDGES)-1:0] cn_rom_addr,
    input logic [19:0]                  cn_rom_data,

    // vn_rom: {cn_index[7:0], edge_id[10:0]} packed 20 bits
    output logic [$clog2(NUM_EDGES)-1:0] vn_rom_addr,
    input logic [19:0]                  vn_rom_data,

    // Stores the actual degree of each variable node.
    output logic [$clog2(NUM_VN)-1:0]    deg_rom_addr,
    input logic [3:0]                   deg_rom_data,

    // CNU interface
    output logic                         cnu_valid_in,
    input logic                          cnu_valid_out,
    output logic signed [MSG_WIDTH-1:0]  cnu_msg_in  [ROW_WEIGHT],
    input logic signed [MSG_WIDTH-1:0]   cnu_msg_out [ROW_WEIGHT],

    // VNU interface
    output logic signed [MSG_WIDTH-1:0]  vnu_msg_in  [MAX_VN_DEG],
    output logic signed [MSG_WIDTH-1:0]  vnu_llr_in,
    output logic [2:0]                   vnu_degree,
    input logic signed [MSG_WIDTH-1:0]   vnu_extrinsic [MAX_VN_DEG],
    input logic signed [MSG_WIDTH-1:0]   vnu_belief,

    // Syndrome checker
    input logic                         syn_pass,
    output logic                        syn_start,
    input logic                         syn_done,

    // Decoded bits
    output logic [$clog2(NUM_VN)-1:0]   dec_wr_addr,
    output logic                        dec_wr_data,
    output logic                        dec_wr_en
);

    typedef enum logic [4:0] {
        S_IDLE,
        S_INIT,
        S_INIT_VN_WAIT,
        S_INIT_LLR_WAIT,
        S_CN_ROM_REQ,
        S_CN_ROM_WAIT,
        S_CN_VC_WAIT,
        S_CN_GATHER,
        S_CN_COMPUTE,
        S_CN_PIPE1,
        S_CN_PIPE2,
        S_CN_PIPE3,
        S_CN_PIPE4,
        S_CN_WRITEBACK,
        S_VN_DEG_REQ,
        S_VN_DEG_WAIT,
        S_VN_ROM_REQ,
        S_VN_ROM_WAIT,
        S_VN_CV_WAIT,
        S_VN_GATHER,
        S_VN_COMPUTE,
        S_VN_WRITEBACK,
        S_SYNDROME,
        S_DONE
    } state_t;

    state_t state;

    logic [$clog2(MAX_ITER)-1:0]     iter_count;
    logic [$clog2(NUM_CN)-1:0]       cn_index;
    logic [$clog2(NUM_VN)-1:0]       vn_index;
    logic [$clog2(ROW_WEIGHT)-1:0]   cn_slot;
    logic [$clog2(MAX_VN_DEG)-1:0]   vn_slot;
    logic [$clog2(NUM_EDGES)-1:0]    init_addr;
    logic [$clog2(NUM_EDGES)-1:0]    vn_edge_base;
    logic [2:0]                      current_vn_degree;

    // Pipeline registers used while initialising the VN-to-CN messages.
    logic [$clog2(NUM_EDGES)-1:0]    init_addr_d1;
    logic [$clog2(NUM_EDGES)-1:0]    init_addr_d2;

    // Temporary buffers for the messages being processed by the CNU and VNU.
    logic signed [MSG_WIDTH-1:0]     cnu_buf      [ROW_WEIGHT];
    logic [$clog2(NUM_EDGES)-1:0]    cn_edge_ids  [ROW_WEIGHT];
    logic signed [MSG_WIDTH-1:0]     vnu_buf      [MAX_VN_DEG];
    logic [$clog2(NUM_EDGES)-1:0]    vn_edge_ids  [MAX_VN_DEG];
    logic signed [MSG_WIDTH-1:0]     llr_lat;
    logic [$clog2(ROW_WEIGHT)-1:0]   cn_wb_slot;
    logic [$clog2(MAX_VN_DEG)-1:0]   vn_wb_slot;

    always_comb begin
        for (int i = 0; i < ROW_WEIGHT;  i++) cnu_msg_in[i] = cnu_buf[i];
        for (int i = 0; i < MAX_VN_DEG; i++) vnu_msg_in[i] = vnu_buf[i];
    end
    assign vnu_llr_in = llr_lat;
    assign vnu_degree = current_vn_degree;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            done              <= 1'b0;
            converged         <= 1'b0;
            iter_count        <= '0;
            cn_index          <= '0;
            vn_index          <= '0;
            cn_slot           <= '0;
            vn_slot           <= '0;
            init_addr         <= '0;
            init_addr_d1      <= '0;
            init_addr_d2      <= '0;
            vn_edge_base      <= '0;
            current_vn_degree <= '0;
            cn_wb_slot        <= '0;
            vn_wb_slot        <= '0;
            llr_lat           <= '0;
            vc_wr_en          <= 1'b0;
            cv_wr_en          <= 1'b0;
            dec_wr_en         <= 1'b0;
            syn_start         <= 1'b0;
            cnu_valid_in      <= 1'b0;
        end else begin
            vc_wr_en     <= 1'b0;
            cv_wr_en     <= 1'b0;
            dec_wr_en    <= 1'b0;
            syn_start    <= 1'b0;
            cnu_valid_in <= 1'b0;

            case (state)

                S_IDLE: begin
                    done      <= 1'b0;
                    converged <= 1'b0;
                    if (start) begin
                        iter_count   <= '0;
                        init_addr    <= '0;
                        init_addr_d1 <= '0;
                        init_addr_d2 <= '0;
                        vn_edge_base <= '0;
                        // Prime the VN adjacency read before starting the initialisation pipeline.
                        vn_rom_addr <= '0;
                        state       <= S_INIT;
                    end
                end

                // Initialise the VN-to-CN bank with the channel LLR for each edge.
                // The ROM and LLR reads are pipelined while the CN-to-VN bank is cleared.
                S_INIT: begin
                    // Request the VN entry for the current edge.
                    vn_rom_addr  <= init_addr[$clog2(NUM_EDGES)-1:0];
                    // Clear the corresponding CN-to-VN message.
                    cv_wr_addr   <= init_addr[$clog2(NUM_EDGES)-1:0];
                    cv_wr_data   <= '0;
                    cv_wr_en     <= 1'b1;
                    init_addr_d1 <= init_addr;
                    if (init_addr < $bits(init_addr)'(NUM_EDGES - 1)) begin
                        init_addr <= init_addr + 1'b1;
                        state     <= S_INIT_VN_WAIT;
                    end else begin
                        init_addr <= init_addr + 1'b1;
                        state     <= S_INIT_VN_WAIT;
                    end
                end

                S_INIT_VN_WAIT: begin
                    // The VN ROM result is available here, so request the corresponding channel LLR.
                    llr_rd_addr  <= vn_rom_data[8:0];
                    init_addr_d2 <= init_addr_d1;
                    // Keep the next edge moving through the pipeline.
                    if (init_addr < $bits(init_addr)'(NUM_EDGES)) begin
                        vn_rom_addr  <= init_addr[$clog2(NUM_EDGES)-1:0];
                        cv_wr_addr   <= init_addr[$clog2(NUM_EDGES)-1:0];
                        cv_wr_data   <= '0;
                        cv_wr_en     <= 1'b1;
                        init_addr_d1 <= init_addr;
                        init_addr    <= init_addr + 1'b1;
                        state        <= S_INIT_LLR_WAIT;
                    end else begin
                        state <= S_INIT_LLR_WAIT;
                    end
                end

                S_INIT_LLR_WAIT: begin
                    // Write the channel LLR to the edge selected by the delayed address.
                    vc_wr_addr <= init_addr_d2;
                    vc_wr_data <= llr_rd_data;
                    vc_wr_en   <= 1'b1;
                    // Continue feeding the pipeline until every edge has been initialised.
                    if (init_addr <= $bits(init_addr)'(NUM_EDGES)) begin
                        llr_rd_addr  <= vn_rom_data[8:0];
                        init_addr_d2 <= init_addr_d1;
                        if (init_addr < $bits(init_addr)'(NUM_EDGES)) begin
                            vn_rom_addr  <= init_addr[$clog2(NUM_EDGES)-1:0];
                            cv_wr_addr   <= init_addr[$clog2(NUM_EDGES)-1:0];
                            cv_wr_data   <= '0;
                            cv_wr_en     <= 1'b1;
                            init_addr_d1 <= init_addr;
                            init_addr    <= init_addr + 1'b1;
                        end
                        if (init_addr_d2 >= $bits(init_addr_d2)'(NUM_EDGES - 1)) begin
                            cn_index <= '0;
                            cn_slot  <= '0;
                            state    <= S_CN_ROM_REQ;
                        end
                    end else begin
                        cn_index <= '0;
                        cn_slot  <= '0;
                        state    <= S_CN_ROM_REQ;
                    end
                end

                // CN phase: gather all VN-to-CN messages for one check node,
                // run the CNU, then write the resulting CN-to-VN messages back.
                S_CN_ROM_REQ: begin
                    cn_rom_addr <= $clog2(NUM_EDGES)'(cn_index * ROW_WEIGHT) + $clog2(NUM_EDGES)'(cn_slot);
                    state       <= S_CN_ROM_WAIT;
                end

                S_CN_ROM_WAIT: begin
                    state <= S_CN_VC_WAIT;
                end

                S_CN_VC_WAIT: begin
                    cn_edge_ids[cn_slot] <= cn_rom_data[19:9];
                    vc_rd_addr           <= cn_rom_data[19:9];
                    state                <= S_CN_GATHER;
                end

                S_CN_GATHER: begin
                    cnu_buf[cn_slot] <= vc_rd_data;
                    if (cn_slot < $bits(cn_slot)'(ROW_WEIGHT - 1)) begin
                        cn_slot <= cn_slot + 1'b1;
                        state   <= S_CN_ROM_REQ;
                    end else begin
                        cn_slot    <= '0;
                        cn_wb_slot <= '0;
                        state      <= S_CN_COMPUTE;
                    end
                end

                S_CN_COMPUTE: begin
                    // Start the CNU pipeline once all messages for the check node are ready.
                    cnu_valid_in <= 1'b1;
                    state        <= S_CN_PIPE1;
                end

                S_CN_PIPE1: begin
                    // Allow the first CNU pipeline stage to complete.
                    state <= S_CN_PIPE2;
                end

                S_CN_PIPE2: begin
                    // Allow the second CNU pipeline stage to complete.
                    state <= S_CN_PIPE3;
                end

                S_CN_PIPE3: begin
                    // Allow the third CNU pipeline stage to complete.
                    state <= S_CN_PIPE4;
                end

                S_CN_PIPE4: begin
                    // The pipelined CNU result is ready for writeback.
                    state <= S_CN_WRITEBACK;
                end

                S_CN_WRITEBACK: begin
                    cv_wr_addr <= cn_edge_ids[cn_wb_slot];
                    cv_wr_data <= cnu_msg_out[cn_wb_slot];
                    cv_wr_en   <= 1'b1;
                    if (cn_wb_slot < $bits(cn_wb_slot)'(ROW_WEIGHT - 1)) begin
                        cn_wb_slot <= cn_wb_slot + 1'b1;
                    end else begin
                        cn_wb_slot <= '0;
                        if (cn_index < $bits(cn_index)'(NUM_CN - 1)) begin
                            cn_index <= cn_index + 1'b1;
                            cn_slot  <= '0;
                            state    <= S_CN_ROM_REQ;
                        end else begin
                            cn_index <= '0;
                            vn_index <= '0;
                            vn_slot  <= '0;
                            state    <= S_VN_DEG_REQ;
                        end
                    end
                end

                // VN phase: load the variable-node degree and all connected
                // CN-to-VN messages before calculating the new VN outputs.
                S_VN_DEG_REQ: begin
                    deg_rom_addr <= vn_index;
                    state        <= S_VN_DEG_WAIT;
                end

                S_VN_DEG_WAIT: begin
                    current_vn_degree <= deg_rom_data[2:0];
                    vn_slot           <= '0;
                    state             <= S_VN_ROM_REQ;
                end

                S_VN_ROM_REQ: begin
                    vn_rom_addr <= vn_edge_base + $clog2(NUM_EDGES)'(vn_slot);
                    state       <= S_VN_ROM_WAIT;
                end

                S_VN_ROM_WAIT: begin
                    state <= S_VN_CV_WAIT;
                end

                S_VN_CV_WAIT: begin
                    vn_edge_ids[vn_slot] <= vn_rom_data[10:0];
                    cv_rd_addr           <= vn_rom_data[10:0];
                    state                <= S_VN_GATHER;
                end

                S_VN_GATHER: begin
                    vnu_buf[vn_slot] <= cv_rd_data;
                    if (vn_slot < $bits(vn_slot)'(int'(current_vn_degree) - 1)) begin
                        vn_slot <= vn_slot + 1'b1;
                        state   <= S_VN_ROM_REQ;
                    end else begin
                        llr_rd_addr <= vn_index;
                        vn_slot     <= '0;
                        vn_wb_slot  <= '0;
                        state       <= S_VN_COMPUTE;
                    end
                end

                S_VN_COMPUTE: begin
                    llr_lat <= llr_rd_data;
                    state   <= S_VN_WRITEBACK;
                end

                S_VN_WRITEBACK: begin
                    vc_wr_addr <= vn_edge_ids[vn_wb_slot];
                    vc_wr_data <= vnu_extrinsic[vn_wb_slot];
                    vc_wr_en   <= 1'b1;
                    if (vn_wb_slot == 0) begin
                        dec_wr_addr <= vn_index;
                        dec_wr_data <= (vnu_belief < 0) ? 1'b1 : 1'b0;
                        dec_wr_en   <= 1'b1;
                    end
                    if (vn_wb_slot < $bits(vn_wb_slot)'(int'(current_vn_degree) - 1)) begin
                        vn_wb_slot <= vn_wb_slot + 1'b1;
                    end else begin
                        vn_wb_slot <= '0;
                        if (vn_index < $bits(vn_index)'(NUM_VN - 1)) begin
                            vn_edge_base <= vn_edge_base + $clog2(NUM_EDGES)'(current_vn_degree);
                            vn_index     <= vn_index + 1'b1;
                            state        <= S_VN_DEG_REQ;
                        end else begin
                            vn_edge_base <= '0;
                            vn_index     <= '0;
                            syn_start    <= 1'b1;
                            state        <= S_SYNDROME;
                        end
                    end
                end

                S_SYNDROME: begin
                    // Check the current hard decisions before starting another iteration.
                    if (syn_done) begin
                        if (syn_pass) begin
                            converged <= 1'b1;
                            done      <= 1'b1;
                            state     <= S_DONE;
                        end else if (iter_count >= $bits(iter_count)'(MAX_ITER - 1)) begin
                            converged <= 1'b0;
                            done      <= 1'b1;
                            state     <= S_DONE;
                        end else begin
                            iter_count <= iter_count + 1'b1;
                            cn_index   <= '0;
                            cn_slot    <= '0;
                            state      <= S_CN_ROM_REQ;
                        end
                    end
                end

                S_DONE: begin
                    if (!start) begin
                        done  <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
