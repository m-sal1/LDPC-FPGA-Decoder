// Variable-node update unit for combining the channel LLR with incoming
// check-node messages and producing extrinsic messages.
// Moustafa Salman

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

    // Limits a wider intermediate value to the configured LLR range.
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

    // The VNU is purely combinational, so all intermediate and output
    // values are assigned for every possible input combination.
    always_comb begin

        // Initialise temporaries to avoid inferred latches.
        total           = '0;
        extrinsic       = '0;
        saturated_value = '0;

        // Combine the channel LLR with all incoming CN-to-VN messages.
        // Unused message slots are driven to zero by the surrounding logic,
        // so including all DEGREE entries does not affect the result.
        total = {{(5){llr_in[WIDTH-1]}}, llr_in};
        for (int i = 0; i < DEGREE; i++)
            total = total + {{(5){msg_in[i][WIDTH-1]}}, msg_in[i]};

        // Saturated a-posteriori LLR used for the hard decision.
        decision_sat = saturate(total);
        decision_llr = decision_sat;

        // Remove each incoming message in turn to form the corresponding
        // extrinsic VN-to-CN message. Entries beyond the active degree
        // are cleared.
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