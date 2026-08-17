// de1_soc_ldpc_top.sv — final version
// KEY[0] released = run, pressed = reset
//
// LEDR[0] = loading LLRs
// LEDR[1] = decoder running (not yet done)
// LEDR[2] = done (latched)
// LEDR[3] = converged / PASS (latched)
// LEDR[4] = not converged / FAIL (latched)
// LEDR[9] = dec_anchor (datapath keepalive)

module de1_soc_ldpc_top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [9:0]  LEDR
);

    logic rst_n;
    assign rst_n = KEY[0];

    // ----------------------------------------------------------------
    // Decoder interface
    // ----------------------------------------------------------------
    logic signed [7:0]  llr_in;
    logic [8:0]         llr_write_addr;
    logic               llr_write_enable;
    logic               start;
    logic               decoding_done;
    logic               converged;
    logic               decoded_bit_out;
    logic [8:0]         decoded_bit_addr;
    logic               decoded_bit_valid;

    // ----------------------------------------------------------------
    // Startup FSM
    // ----------------------------------------------------------------
    typedef enum logic [1:0] {
        S_LOAD  = 2'b00,
        S_START = 2'b01,
        S_RUN   = 2'b10
    } top_state_t;

    top_state_t top_state;
    logic [8:0] load_addr;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            top_state <= S_LOAD;
            load_addr <= 9'd0;
        end else begin
            case (top_state)
                S_LOAD: begin
                    if (load_addr == 9'd511) begin
                        load_addr <= 9'd0;
                        top_state <= S_START;
                    end else
                        load_addr <= load_addr + 9'd1;
                end
                S_START: top_state <= S_RUN;
                S_RUN:   top_state <= S_RUN;
                default: top_state <= S_LOAD;
            endcase
        end
    end

    assign llr_in           = 8'sd32;
    assign llr_write_addr   = load_addr;
    assign llr_write_enable = (top_state == S_LOAD);
    assign start            = (top_state == S_START);

    // ----------------------------------------------------------------
    // Decoder
    // ----------------------------------------------------------------
    qc_ldpc_decoder_top #(
        .MSG_WIDTH (8),
        .Z         (8),
        .MB        (32),
        .NB        (64),
        .MAX_ROW_W (6),
        .MAX_COL_W (3),
        .NUM_VN    (512),
        .NUM_CN    (256),
        .MAX_ITER  (50)
    ) decoder (
        .clk              (CLOCK_50),
        .rst_n            (rst_n),
        .llr_in           (llr_in),
        .llr_write_addr   (llr_write_addr),
        .llr_write_enable (llr_write_enable),
        .start            (start),
        .decoding_done    (decoding_done),
        .converged        (converged),
        .decoded_bit_out  (decoded_bit_out),
        .decoded_bit_addr (decoded_bit_addr),
        .decoded_bit_valid(decoded_bit_valid)
    );

    // ----------------------------------------------------------------
    // Latch done and converged — hold result until next reset
    // ----------------------------------------------------------------
    logic done_latched;
    logic conv_latched;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            done_latched <= 1'b0;
            conv_latched <= 1'b0;
        end else begin
            if (decoding_done) done_latched <= 1'b1;
            if (converged)     conv_latched <= 1'b1;
        end
    end

    // ----------------------------------------------------------------
    // Datapath anchor
    // ----------------------------------------------------------------
    (* keep *) logic [7:0] dec_shift;
    (* keep *) logic       dec_anchor;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            dec_shift  <= 8'b0;
            dec_anchor <= 1'b0;
        end else if (decoded_bit_valid) begin
            dec_shift  <= {dec_shift[6:0], decoded_bit_out};
            dec_anchor <= dec_shift[7] ^ conv_latched ^ done_latched;
        end
    end

    // ----------------------------------------------------------------
    // LEDs
    // ----------------------------------------------------------------
    always_comb begin
        LEDR    = 10'b0;
        LEDR[0] = (top_state == S_LOAD);
        LEDR[1] = (top_state == S_RUN) && !done_latched;
        LEDR[2] = done_latched;
        LEDR[3] = done_latched &&  conv_latched;   // PASS
        LEDR[4] = done_latched && !conv_latched;   // FAIL
        LEDR[9] = dec_anchor;
    end

endmodule
