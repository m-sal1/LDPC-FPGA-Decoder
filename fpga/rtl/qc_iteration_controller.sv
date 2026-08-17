// qc_iteration_controller.sv
// Controls the QC-LDPC decoding schedule, memory accesses, node updates, and iteration flow.
// Moustafa Salman

module qc_iteration_controller #(
    parameter int Z           = 8,
    parameter int MB          = 32,
    parameter int NB          = 64,
    parameter int MAX_ROW_W   = 6,
    parameter int MAX_COL_W   = 3,
    parameter int CIRC_DEPTH  = 192,
    parameter int MSG_WIDTH   = 8,
    parameter int MAX_ITER    = 50
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,
    output logic converged,

    output logic [$clog2(NB)-1:0]            llr_rd_bcol,
    input logic signed [MSG_WIDTH-1:0]      llr_rd_data [0:Z-1],

    output logic [$clog2(CIRC_DEPTH)-1:0]    vc_rd_addr,
    output logic                              vc_rd_en,
    input logic signed [MSG_WIDTH-1:0]      vc_rd_data [0:Z-1],
    output logic [$clog2(CIRC_DEPTH)-1:0]    vc_wr_addr,
    output logic                              vc_wr_en,
    output logic signed [MSG_WIDTH-1:0]      vc_wr_data [0:Z-1],

    output logic [$clog2(CIRC_DEPTH)-1:0]    cv_rd_addr,
    output logic                              cv_rd_en,
    input logic signed [MSG_WIDTH-1:0]      cv_rd_data [0:Z-1],
    output logic [$clog2(CIRC_DEPTH)-1:0]    cv_wr_addr,
    output logic                              cv_wr_en,
    output logic signed [MSG_WIDTH-1:0]      cv_wr_data [0:Z-1],

    output logic [7:0]   cn_rom_addr,
    input logic [8:0]   cn_rom_data,

    output logic [7:0]   vn_rom_addr,
    input logic [7:0]   vn_rom_data,

    output logic [7:0]   vn_cn_slot_addr,
    input logic [2:0]   vn_cn_slot_data,

    output logic [4:0]   row_w_addr,
    input logic [2:0]   row_w_data,

    output logic [5:0]   col_w_addr,
    input logic [1:0]   col_w_data,

    output logic signed [MSG_WIDTH-1:0]  shift_in  [0:Z-1],
    output logic [$clog2(Z)-1:0]         shift_amt,
    input logic signed [MSG_WIDTH-1:0]  shift_out [0:Z-1],

    output logic                          cnu_valid_in,
    input logic                          cnu_valid_out,
    output logic signed [MSG_WIDTH-1:0]  cnu_msg_in  [0:Z-1][0:MAX_ROW_W-1],
    input logic signed [MSG_WIDTH-1:0]  cnu_msg_out [0:Z-1][0:MAX_ROW_W-1],

    output logic signed [MSG_WIDTH-1:0]  vnu_msg_in    [0:Z-1][0:MAX_COL_W-1],
    output logic signed [MSG_WIDTH-1:0]  vnu_llr_in    [0:Z-1],
    output logic [2:0]                   vnu_degree,
    input logic signed [MSG_WIDTH-1:0]  vnu_extrinsic [0:Z-1][0:MAX_COL_W-1],
    input logic signed [MSG_WIDTH-1:0]  vnu_belief    [0:Z-1],

    input logic        syn_pass,
    output logic        syn_start,
    input logic        syn_done,

    output logic [$clog2(NB)-1:0] dec_wr_bcol,
    output logic [Z-1:0]          dec_wr_data,
    output logic                   dec_wr_en
);

    typedef enum logic [4:0] {
        S_IDLE,
        S_INIT,
        S_CN_RW_REQ,
        S_CN_RW_WAIT,
        S_CN_ROM_REQ,
        S_CN_ROM_WAIT,
        S_CN_RD,
        S_CN_RD_WAIT,
        S_CN_LATCH,
        S_CNU_FIRE, S_CNU_P1, S_CNU_P2, S_CNU_P3, S_CNU_P4,
        S_CN_WB_PREP, S_CN_WB_SHIFT, S_CN_WB_WRITE,
        S_VN_CW_REQ,
        S_VN_CW_WAIT,
        S_VN_ROM_REQ,
        S_VN_ROM_WAIT,
        S_VN_RD,
        S_VN_RD_WAIT,
        S_VN_LATCH,
        S_VNU_COMPUTE,
        S_VN_WB_PREP, S_VN_WB_SHIFT, S_VN_WB_WRITE,
        S_SYNDROME,
        S_DONE
    } state_t;

    state_t state;

    logic [$clog2(MB)-1:0]         brow;
    logic [$clog2(NB)-1:0]         bcol;
    logic [$clog2(MAX_ROW_W)-1:0]  cn_slot;
    logic [$clog2(MAX_COL_W)-1:0]  vn_slot;
    logic [$clog2(MAX_ROW_W)-1:0]  wb_slot;
    logic [$clog2(MAX_ITER):0]      iter;
    logic [7:0]                     init_addr;

    logic [2:0]  cur_row_w;
    logic [1:0]  cur_col_w;

    // Latched connectivity and shift values used during message writeback.
    logic [5:0]  lat_cn_bcol    [0:MAX_ROW_W-1];
    logic [2:0]  lat_cn_shift   [0:MAX_ROW_W-1];
    logic [4:0]  lat_vn_brow    [0:MAX_COL_W-1];
    logic [2:0]  lat_vn_shift   [0:MAX_COL_W-1];
    logic [2:0]  lat_vn_cn_slot [0:MAX_COL_W-1];

    // Buffers hold the messages gathered for the current check or variable node.
    logic signed [MSG_WIDTH-1:0] cnu_buf [0:Z-1][0:MAX_ROW_W-1];
    logic signed [MSG_WIDTH-1:0] vnu_buf [0:Z-1][0:MAX_COL_W-1];
    logic signed [MSG_WIDTH-1:0] llr_buf [0:Z-1];

    always_comb begin
        for (int z = 0; z < Z; z++) begin
            for (int s = 0; s < MAX_ROW_W; s++) cnu_msg_in[z][s] = cnu_buf[z][s];
            for (int s = 0; s < MAX_COL_W; s++) vnu_msg_in[z][s] = vnu_buf[z][s];
            vnu_llr_in[z] = llr_buf[z];
        end
    end

    assign vnu_degree = {1'b0, cur_col_w};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            done         <= 1'b0;
            converged    <= 1'b0;
            iter         <= '0;
            brow         <= '0;
            bcol         <= '0;
            cn_slot      <= '0;
            vn_slot      <= '0;
            wb_slot      <= '0;
            init_addr    <= '0;
            cur_row_w    <= '0;
            cur_col_w    <= '0;
            vc_rd_en     <= 1'b0;
            vc_wr_en     <= 1'b0;
            cv_rd_en     <= 1'b0;
            cv_wr_en     <= 1'b0;
            dec_wr_en    <= 1'b0;
            syn_start    <= 1'b0;
            cnu_valid_in <= 1'b0;
            shift_amt    <= '0;
            for (int z = 0; z < Z; z++) shift_in[z] <= '0;
        end else begin
            vc_rd_en     <= 1'b0;
            vc_wr_en     <= 1'b0;
            cv_rd_en     <= 1'b0;
            cv_wr_en     <= 1'b0;
            dec_wr_en    <= 1'b0;
            syn_start    <= 1'b0;
            cnu_valid_in <= 1'b0;

            case (state)

                S_IDLE: begin
                    done <= 1'b0; converged <= 1'b0;
                    if (start) begin
                        iter <= '0; init_addr <= '0;
                        state <= S_INIT;
                    end
                end

                // Clear all padded message-bank entries before decoding starts.
                S_INIT: begin
                    vc_wr_addr <= init_addr[7:0];
                    cv_wr_addr <= init_addr[7:0];
                    vc_wr_en   <= 1'b1;
                    cv_wr_en   <= 1'b1;
                    for (int k = 0; k < Z; k++) begin
                        vc_wr_data[k] <= '0;
                        cv_wr_data[k] <= '0;
                    end

                    if (init_addr < 8'(CIRC_DEPTH - 1)) begin
                        init_addr <= init_addr + 8'd1;
                    end else begin
                        brow    <= '0;
                        cn_slot <= '0;
                        state   <= S_CN_RW_REQ;
                    end
                end

                // Read the current check-node row weight before gathering its messages.
                S_CN_RW_REQ: begin
                    row_w_addr <= brow;
                    state      <= S_CN_RW_WAIT;
                end

                S_CN_RW_WAIT: begin
                    // Use the maximum row weight if the ROM entry is zero.
                    cur_row_w <= (row_w_data == 3'b0) ? 3'(MAX_ROW_W) : row_w_data;
                    cn_slot   <= '0;
                    state     <= S_CN_ROM_REQ;
                end

                S_CN_ROM_REQ: begin
                    // The padded address is shared by the CN and VN message phases.
                    cn_rom_addr <= 8'(brow * MAX_ROW_W + cn_slot);
                    state       <= S_CN_ROM_WAIT;
                end

                S_CN_ROM_WAIT: state <= S_CN_RD;

                S_CN_RD: begin
                    lat_cn_bcol[cn_slot]  <= cn_rom_data[8:3];
                    lat_cn_shift[cn_slot] <= cn_rom_data[2:0];
                    vc_rd_addr <= 8'(brow * MAX_ROW_W + cn_slot);
                    vc_rd_en   <= 1'b1;

                    // Rotate the stored message back into the check-node ordering.
                    shift_amt  <= ($clog2(Z))'(Z - cn_rom_data[2:0]);
                    state      <= S_CN_RD_WAIT;
                end

                S_CN_RD_WAIT: begin
                    for (int k = 0; k < Z; k++) shift_in[k] <= vc_rd_data[k];
                    state <= S_CN_LATCH;
                end

                S_CN_LATCH: begin
                    for (int z = 0; z < Z; z++) cnu_buf[z][cn_slot] <= shift_out[z];
                    if (cn_slot < $bits(cn_slot)'(cur_row_w - 1)) begin
                        cn_slot <= cn_slot + 1'b1;
                        state   <= S_CN_ROM_REQ;
                    end else begin
                        cn_slot      <= '0;
                        cnu_valid_in <= 1'b1;
                        state        <= S_CNU_FIRE;
                    end
                end

                // Wait for the four-stage CNU pipeline to produce its outputs.
                S_CNU_FIRE: state <= S_CNU_P1;
                S_CNU_P1:   state <= S_CNU_P2;
                S_CNU_P2:   state <= S_CNU_P3;
                S_CNU_P3:   state <= S_CNU_P4;
                S_CNU_P4: begin wb_slot <= '0; state <= S_CN_WB_PREP; end

                S_CN_WB_PREP: begin
                    shift_amt <= lat_cn_shift[wb_slot];
                    for (int z = 0; z < Z; z++) shift_in[z] <= cnu_msg_out[z][wb_slot];
                    state <= S_CN_WB_SHIFT;
                end

                S_CN_WB_SHIFT: state <= S_CN_WB_WRITE;

                S_CN_WB_WRITE: begin
                    // Store the updated CN-to-VN message using the padded address.
                    cv_wr_addr <= 8'(brow * MAX_ROW_W + wb_slot);
                    cv_wr_en   <= 1'b1;
                    for (int z = 0; z < Z; z++) cv_wr_data[z] <= shift_out[z];

                    if (wb_slot < $bits(wb_slot)'(cur_row_w - 1)) begin
                        wb_slot <= wb_slot + 1'b1;
                        state   <= S_CN_WB_PREP;
                    end else begin
                        wb_slot <= '0;
                        if (brow < $bits(brow)'(MB - 1)) begin
                            brow    <= brow + 1'b1;
                            cn_slot <= '0;
                            state   <= S_CN_RW_REQ;
                        end else begin
                            brow    <= '0;
                            bcol    <= '0;
                            vn_slot <= '0;
                            state   <= S_VN_CW_REQ;
                        end
                    end
                end

                // Read the current variable-node column weight before gathering messages.
                S_VN_CW_REQ: begin
                    col_w_addr <= bcol;
                    state      <= S_VN_CW_WAIT;
                end

                S_VN_CW_WAIT: begin
                    // Use the maximum column weight if the ROM entry is zero.
                    cur_col_w <= (col_w_data == 2'b0) ? 2'(MAX_COL_W) : col_w_data;
                    vn_slot   <= '0;
                    state     <= S_VN_ROM_REQ;
                end

                S_VN_ROM_REQ: begin
                    // The VN connectivity tables use the same padded column-slot layout.
                    vn_rom_addr     <= 8'(bcol * MAX_COL_W + vn_slot);
                    vn_cn_slot_addr <= 8'(bcol * MAX_COL_W + vn_slot);
                    llr_rd_bcol     <= bcol;
                    state           <= S_VN_ROM_WAIT;
                end

                S_VN_ROM_WAIT: begin
                    for (int z = 0; z < Z; z++) llr_buf[z] <= llr_rd_data[z];
                    state <= S_VN_RD;
                end

                S_VN_RD: begin
                    lat_vn_brow[vn_slot]    <= vn_rom_data[7:3];
                    lat_vn_shift[vn_slot]   <= vn_rom_data[2:0];
                    lat_vn_cn_slot[vn_slot] <= vn_cn_slot_data;

                    // Convert the stored row and slot into the padded message address.
                    cv_rd_addr <= 8'(vn_rom_data[7:3] * MAX_ROW_W + vn_cn_slot_data);
                    cv_rd_en   <= 1'b1;

                    // Rotate the CN-to-VN message back into the VN ordering.
                    shift_amt  <= ($clog2(Z))'(Z - vn_rom_data[2:0]);
                    state      <= S_VN_RD_WAIT;
                end

                S_VN_RD_WAIT: begin
                    for (int k = 0; k < Z; k++) shift_in[k] <= cv_rd_data[k];
                    state <= S_VN_LATCH;
                end

                S_VN_LATCH: begin
                    for (int z = 0; z < Z; z++) vnu_buf[z][vn_slot] <= shift_out[z];
                    if (vn_slot < $bits(vn_slot)'(cur_col_w - 1)) begin
                        vn_slot <= vn_slot + 1'b1;
                        state   <= S_VN_ROM_REQ;
                    end else begin
                        vn_slot <= '0;
                        state   <= S_VNU_COMPUTE;
                    end
                end

                S_VNU_COMPUTE: begin
                    for (int z = 0; z < Z; z++)
                        dec_wr_data[z] <= (vnu_belief[z] < 0) ? 1'b1 : 1'b0;
                    dec_wr_bcol <= bcol;
                    dec_wr_en   <= 1'b1;
                    wb_slot     <= '0;
                    state       <= S_VN_WB_PREP;
                end

                S_VN_WB_PREP: begin
                    shift_amt <= lat_vn_shift[wb_slot];
                    for (int z = 0; z < Z; z++) shift_in[z] <= vnu_extrinsic[z][wb_slot];
                    state <= S_VN_WB_SHIFT;
                end

                S_VN_WB_SHIFT: state <= S_VN_WB_WRITE;

                S_VN_WB_WRITE: begin
                    // Store the updated VN-to-CN message using the padded row and slot.
                    vc_wr_addr <= 8'(lat_vn_brow[wb_slot] * MAX_ROW_W +
                                     lat_vn_cn_slot[wb_slot]);
                    vc_wr_en   <= 1'b1;
                    for (int z = 0; z < Z; z++) vc_wr_data[z] <= shift_out[z];

                    if (wb_slot < $bits(wb_slot)'(cur_col_w - 1)) begin
                        wb_slot <= wb_slot + 1'b1;
                        state   <= S_VN_WB_PREP;
                    end else begin
                        wb_slot <= '0;
                        if (bcol < $bits(bcol)'(NB - 1)) begin
                            bcol    <= bcol + 1'b1;
                            vn_slot <= '0;
                            state   <= S_VN_CW_REQ;
                        end else begin
                            bcol      <= '0;
                            syn_start <= 1'b1;
                            state     <= S_SYNDROME;
                        end
                    end
                end

                // Wait for the syndrome result before either stopping or starting
                // another CN/VN flooding iteration.
                S_SYNDROME: begin
                    if (syn_done) begin
                        if (syn_pass) begin
                            converged <= 1'b1;
                            done      <= 1'b1;
                            state     <= S_DONE;
                        end else if (iter >= ($bits(iter))'(MAX_ITER - 1)) begin
                            done  <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            iter    <= iter + 1'b1;
                            brow    <= '0;
                            cn_slot <= '0;
                            state   <= S_CN_RW_REQ;
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
