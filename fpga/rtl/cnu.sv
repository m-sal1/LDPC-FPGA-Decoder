// =============================================================================
// cnu.sv — Check Node Unit, 4-stage pipeline
//
// Splits min-search over 8 inputs into parallel half-searches then merge,
// halving the combinational depth of the critical path to ~8ns per stage.
//
// Stage 1: abs values + overall sign        (comb → registered)
// Stage 2: parallel min-search left [0..3]  (comb → registered)
//          parallel min-search right [4..7] (comb → registered, same cycle)
// Stage 3: merge left/right min results     (comb → registered)
// Stage 4: output scaling + sign            (comb → registered)
//
// 4 clock cycles input-to-output latency.
// Each combinational stage ~8ns → closes at 50MHz on Cyclone V.


module cnu #(
    parameter int DEGREE = 8,
    parameter int WIDTH  = 8
)(
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      valid_in,
    input  logic signed [WIDTH-1:0]   msg_in  [0:DEGREE-1],
    output logic                      valid_out,
    output logic signed [WIDTH-1:0]   msg_out [0:DEGREE-1]
);

    localparam IDX_WIDTH = $clog2(DEGREE);
    localparam HALF      = DEGREE / 2;   // 4

    // =========================================================================
    // Stage 1: absolute values + overall sign
    // =========================================================================
    logic                     valid_s1;
    logic                     overall_sign_s1;
    logic [WIDTH-1:0]         abs_vals_s1  [0:DEGREE-1];
    logic                     sign_bits_s1 [0:DEGREE-1];

    logic                     c1_overall_sign;
    logic [WIDTH-1:0]         c1_abs  [0:DEGREE-1];
    logic                     c1_sign [0:DEGREE-1];

    always_comb begin
        c1_overall_sign = 1'b0;
        for (int i = 0; i < DEGREE; i++) begin
            c1_sign[i]      = msg_in[i][WIDTH-1];
            c1_overall_sign = c1_overall_sign ^ c1_sign[i];
            c1_abs[i]       = msg_in[i][WIDTH-1] ? -msg_in[i] : msg_in[i];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_s1        <= 1'b0;
            overall_sign_s1 <= 1'b0;
            for (int j = 0; j < DEGREE; j++) begin
                abs_vals_s1[j]  <= '0;
                sign_bits_s1[j] <= 1'b0;
            end
        end else begin
            valid_s1 <= valid_in;
            if (valid_in) begin
                overall_sign_s1 <= c1_overall_sign;
                for (int j = 0; j < DEGREE; j++) begin
                    abs_vals_s1[j]  <= c1_abs[j];
                    sign_bits_s1[j] <= c1_sign[j];
                end
            end
        end
    end

    // =========================================================================
    // Stage 2: parallel half min-searches (left [0..3], right [4..7])
    // Both run combinationally from stage 1 registers in the SAME cycle.
    // =========================================================================
    logic                     valid_s2;
    logic                     overall_sign_s2;
    logic                     sign_bits_s2  [0:DEGREE-1];

    // Left half result
    logic [WIDTH-1:0]         lmin1_s2;
    logic [WIDTH-1:0]         lmin2_s2;
    logic [IDX_WIDTH-1:0]     lmin1_idx_s2;   // global index (0..3)

    // Right half result
    logic [WIDTH-1:0]         rmin1_s2;
    logic [WIDTH-1:0]         rmin2_s2;
    logic [IDX_WIDTH-1:0]     rmin1_idx_s2;   // global index (4..7)

    // Combinational left half
    logic [WIDTH-1:0]         c2_lmin1, c2_lmin2;
    logic [IDX_WIDTH-1:0]     c2_lmin1_idx;

    always_comb begin
        c2_lmin1     = {WIDTH{1'b1}};
        c2_lmin2     = {WIDTH{1'b1}};
        c2_lmin1_idx = '0;
        for (int i = 0; i < HALF; i++) begin
            if (abs_vals_s1[i] < c2_lmin1) begin
                c2_lmin2     = c2_lmin1;
                c2_lmin1     = abs_vals_s1[i];
                c2_lmin1_idx = i[IDX_WIDTH-1:0];
            end else if (abs_vals_s1[i] < c2_lmin2) begin
                c2_lmin2 = abs_vals_s1[i];
            end
        end
    end

    // Combinational right half
    logic [WIDTH-1:0]         c2_rmin1, c2_rmin2;
    logic [IDX_WIDTH-1:0]     c2_rmin1_idx;

    always_comb begin
        c2_rmin1     = {WIDTH{1'b1}};
        c2_rmin2     = {WIDTH{1'b1}};
        c2_rmin1_idx = IDX_WIDTH'(HALF);   // start index at 4
        for (int i = HALF; i < DEGREE; i++) begin
            if (abs_vals_s1[i] < c2_rmin1) begin
                c2_rmin2     = c2_rmin1;
                c2_rmin1     = abs_vals_s1[i];
                c2_rmin1_idx = i[IDX_WIDTH-1:0];
            end else if (abs_vals_s1[i] < c2_rmin2) begin
                c2_rmin2 = abs_vals_s1[i];
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_s2        <= 1'b0;
            overall_sign_s2 <= 1'b0;
            lmin1_s2        <= '0;
            lmin2_s2        <= '0;
            lmin1_idx_s2    <= '0;
            rmin1_s2        <= '0;
            rmin2_s2        <= '0;
            rmin1_idx_s2    <= '0;
            for (int j = 0; j < DEGREE; j++)
                sign_bits_s2[j] <= 1'b0;
        end else begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                overall_sign_s2 <= overall_sign_s1;
                lmin1_s2        <= c2_lmin1;
                lmin2_s2        <= c2_lmin2;
                lmin1_idx_s2    <= c2_lmin1_idx;
                rmin1_s2        <= c2_rmin1;
                rmin2_s2        <= c2_rmin2;
                rmin1_idx_s2    <= c2_rmin1_idx;
                for (int j = 0; j < DEGREE; j++)
                    sign_bits_s2[j] <= sign_bits_s1[j];
            end
        end
    end

    // =========================================================================
    // Stage 3: merge left/right results -> overall min1/min2
    // Only 4 candidates: lmin1, lmin2, rmin1, rmin2
    // Much cheaper than 8-input search.
    // =========================================================================
    logic                     valid_s3;
    logic                     overall_sign_s3;
    logic                     sign_bits_s3 [0:DEGREE-1];
    logic [WIDTH-1:0]         min1_s3;
    logic [WIDTH-1:0]         min2_s3;
    logic [IDX_WIDTH-1:0]     min1_idx_s3;

    logic [WIDTH-1:0]         c3_min1, c3_min2;
    logic [IDX_WIDTH-1:0]     c3_min1_idx;

    always_comb begin
        // Compare the two halves' minimums
        if (lmin1_s2 <= rmin1_s2) begin
            // Left has smaller min1
            c3_min1     = lmin1_s2;
            c3_min1_idx = lmin1_idx_s2;
            // min2 is smallest of lmin2, rmin1
            if (lmin2_s2 <= rmin1_s2) begin
                c3_min2 = lmin2_s2;
            end else begin
                c3_min2 = rmin1_s2;
            end
        end else begin
            // Right has smaller min1
            c3_min1     = rmin1_s2;
            c3_min1_idx = rmin1_idx_s2;
            // min2 is smallest of rmin2, lmin1
            if (rmin2_s2 <= lmin1_s2) begin
                c3_min2 = rmin2_s2;
            end else begin
                c3_min2 = lmin1_s2;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_s3        <= 1'b0;
            overall_sign_s3 <= 1'b0;
            min1_s3         <= '0;
            min2_s3         <= '0;
            min1_idx_s3     <= '0;
            for (int j = 0; j < DEGREE; j++)
                sign_bits_s3[j] <= 1'b0;
        end else begin
            valid_s3 <= valid_s2;
            if (valid_s2) begin
                overall_sign_s3 <= overall_sign_s2;
                min1_s3         <= c3_min1;
                min2_s3         <= c3_min2;
                min1_idx_s3     <= c3_min1_idx;
                for (int j = 0; j < DEGREE; j++)
                    sign_bits_s3[j] <= sign_bits_s2[j];
            end
        end
    end

    // =========================================================================
    // Stage 4: output scaling + sign assignment
    // =========================================================================
    logic signed [WIDTH-1:0]  c4_msg_out [0:DEGREE-1];

    always_comb begin
        for (int i = 0; i < DEGREE; i++) begin
            logic                sign;
            logic [WIDTH-1:0]    val, att;
            sign = overall_sign_s3 ^ sign_bits_s3[i];
            val  = (i[IDX_WIDTH-1:0] == min1_idx_s3) ? min2_s3 : min1_s3;
            att  = val - (val >> 2);
            c4_msg_out[i] = sign ? -$signed(att) : $signed(att);
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            for (int j = 0; j < DEGREE; j++)
                msg_out[j] <= '0;
        end else begin
            valid_out <= valid_s3;
            if (valid_s3) begin
                for (int j = 0; j < DEGREE; j++)
                    msg_out[j] <= c4_msg_out[j];
            end
        end
    end

endmodule
