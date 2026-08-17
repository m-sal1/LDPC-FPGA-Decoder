// cnu.sv
// Pipelined check-node unit for the LDPC decoder.
// Computes the two smallest input magnitudes and applies the required sign and scaling to each output.
// Moustafa Salman

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
    localparam HALF      = DEGREE / 2;

    // Stage 1 stores the magnitude and sign of every input message,
    // along with the XOR of all input signs.

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

    // Search the two halves independently. This reduces the number of
    // values that need to be compared in the following merge stage.

    logic                     valid_s2;
    logic                     overall_sign_s2;
    logic                     sign_bits_s2  [0:DEGREE-1];

    logic [WIDTH-1:0]         lmin1_s2;
    logic [WIDTH-1:0]         lmin2_s2;
    logic [IDX_WIDTH-1:0]     lmin1_idx_s2;

    logic [WIDTH-1:0]         rmin1_s2;
    logic [WIDTH-1:0]         rmin2_s2;
    logic [IDX_WIDTH-1:0]     rmin1_idx_s2;

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

    logic [WIDTH-1:0]         c2_rmin1, c2_rmin2;
    logic [IDX_WIDTH-1:0]     c2_rmin1_idx;

    always_comb begin
        c2_rmin1     = {WIDTH{1'b1}};
        c2_rmin2     = {WIDTH{1'b1}};
        c2_rmin1_idx = IDX_WIDTH'(HALF);
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

    // Merge the two half-search results. Only four candidates are needed
    // to determine the global minimum and second minimum.

    logic                     valid_s3;
    logic                     overall_sign_s3;
    logic                     sign_bits_s3 [0:DEGREE-1];
    logic [WIDTH-1:0]         min1_s3;
    logic [WIDTH-1:0]         min2_s3;
    logic [IDX_WIDTH-1:0]     min1_idx_s3;

    logic [WIDTH-1:0]         c3_min1, c3_min2;
    logic [IDX_WIDTH-1:0]     c3_min1_idx;

    always_comb begin
        if (lmin1_s2 <= rmin1_s2) begin
            c3_min1     = lmin1_s2;
            c3_min1_idx = lmin1_idx_s2;
            if (lmin2_s2 <= rmin1_s2) begin
                c3_min2 = lmin2_s2;
            end else begin
                c3_min2 = rmin1_s2;
            end
        end else begin
            c3_min1     = rmin1_s2;
            c3_min1_idx = rmin1_idx_s2;
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

    // Apply the normalized min-sum scaling and restore the appropriate
    // sign for each outgoing CN-to-VN message.

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
