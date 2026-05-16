module vnu #(

    parameter DEGREE = 3,
    parameter WIDTH  = 8

)(

    input  logic signed [WIDTH-1:0] llr_in,
    input  logic signed [WIDTH-1:0] msg_in [0:DEGREE-1],

    output logic signed [WIDTH-1:0] msg_out [0:DEGREE-1],
    output logic signed [WIDTH-1:0] decision_llr

);

    integer i;

    // Extra headroom for accumulation
    logic signed [WIDTH+2:0] total;
    logic signed [WIDTH+2:0] extrinsic;

    logic signed [WIDTH-1:0] saturated_value;
    logic signed [WIDTH-1:0] decision_sat;

    // Saturation helper
    function automatic signed [WIDTH-1:0] saturate;

        input signed [WIDTH+2:0] value;

        localparam signed [WIDTH+2:0] MAX_VAL =
            (2**(WIDTH-1)) - 1;

        localparam signed [WIDTH+2:0] MIN_VAL =
            -(2**(WIDTH-1));

        begin

            if (value > MAX_VAL)
                saturate = MAX_VAL[WIDTH-1:0];

            else if (value < MIN_VAL)
                saturate = MIN_VAL[WIDTH-1:0];

            else
                saturate = value[WIDTH-1:0];

        end

    endfunction

    always_comb begin

        // Total belief accumulation
        total = llr_in;

        for (i = 0; i < DEGREE; i++) begin
            total = total + $signed(msg_in[i]);
        end

        // Final decision LLR
        decision_sat = saturate(total);

        decision_llr = decision_sat;

        // Extrinsic message generation
        for (i = 0; i < DEGREE; i++) begin

            extrinsic = total - $signed(msg_in[i]);

            saturated_value = saturate(extrinsic);

            msg_out[i] = saturated_value;

        end

    end

endmodule
