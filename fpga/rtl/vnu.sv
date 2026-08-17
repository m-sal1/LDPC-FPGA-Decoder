module vnu #(
    parameter int DEGREE = 5,
    parameter int WIDTH  = 8
)(
    input  logic signed [WIDTH-1:0] llr_in,
    input  logic signed [WIDTH-1:0] msg_in [0:DEGREE-1],
    input  logic [2:0]              degree,
    output logic signed [WIDTH-1:0] msg_out [0:DEGREE-1],
    output logic signed [WIDTH-1:0] decision_llr
);

    // Accumulator headroom: DEGREE=5, WIDTH=8 -> max sum = 5*127 = 635
    // WIDTH+4 = 12 bits signed is sufficient
    logic signed [WIDTH+4:0] total;
    logic signed [WIDTH+4:0] extrinsic;
    logic signed [WIDTH-1:0] saturated_value;
    logic signed [WIDTH-1:0] decision_sat;

    // ── Saturation helper ─────────────────────────────────────────────────────
    function automatic signed [WIDTH-1:0] saturate;
        input signed [WIDTH+4:0] value;
        localparam signed [WIDTH+4:0] MAX_VAL =  (2**(WIDTH-1)) - 1;
        localparam signed [WIDTH+4:0] MIN_VAL = -(2**(WIDTH-1));
        begin
            if      (value > MAX_VAL) saturate = MAX_VAL[WIDTH-1:0];
            else if (value < MIN_VAL) saturate = MIN_VAL[WIDTH-1:0];
            else                      saturate = value[WIDTH-1:0];
        end
    endfunction

    // ── Combinational datapath ────────────────────────────────────────────────
    always_comb begin

        // Initialise temporaries — prevents latch inference
        total           = '0;
        extrinsic       = '0;
        saturated_value = '0;

        // Accumulate: channel LLR + all incoming CN->VN messages.
        // Unused slots (index >= degree) are driven to 0 by the FSM,
        // so summing all DEGREE slots is always safe.
        total = {{(5){llr_in[WIDTH-1]}}, llr_in};
        for (int i = 0; i < DEGREE; i++)
            total = total + {{(5){msg_in[i][WIDTH-1]}}, msg_in[i]};

        // Decision LLR
        decision_sat = saturate(total);
        decision_llr = decision_sat;

        // Extrinsic messages for valid slots; zero for unused slots
        for (int i = 0; i < DEGREE; i++) begin
            if (i < int'(degree)) begin
                extrinsic       = total - {{(5){msg_in[i][WIDTH-1]}}, msg_in[i]};
                saturated_value = saturate(extrinsic);
                msg_out[i]      = saturated_value;
            end else begin
                msg_out[i] = '0;
            end
        end

    end

endmodule
