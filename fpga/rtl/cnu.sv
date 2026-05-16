module cnu #(

    parameter DEGREE = 8,
    parameter WIDTH  = 8

)(

    input  logic signed [WIDTH-1:0] msg_in [0:DEGREE-1],
    output logic signed [WIDTH-1:0] msg_out[0:DEGREE-1]

);

    integer i;

    logic sign_bits [0:DEGREE-1];
    logic overall_sign;

    logic [WIDTH-1:0] abs_vals [0:DEGREE-1];

    logic [WIDTH-1:0] min1;
    logic [WIDTH-1:0] min2;

    integer min1_idx;

    logic sign;
    logic [WIDTH-1:0] val;
    logic [WIDTH-1:0] attenuated_val;

    always_comb begin

        // DEFAULTS

        overall_sign = 1'b0;

        min1 = {WIDTH{1'b1}};
        min2 = {WIDTH{1'b1}};

        min1_idx = 0;

        // ABS + SIGN EXTRACTION

        for (i = 0; i < DEGREE; i++) begin

            sign_bits[i] = msg_in[i][WIDTH-1];

            overall_sign = overall_sign ^ sign_bits[i];

            if (msg_in[i] < 0)
                abs_vals[i] = -msg_in[i];
            else
                abs_vals[i] = msg_in[i];

        end

        // FIND MIN1 / MIN2

        for (i = 0; i < DEGREE; i++) begin

            if (abs_vals[i] < min1) begin

                min2 = min1;
                min1 = abs_vals[i];

                min1_idx = i;

            end
            else if (abs_vals[i] < min2) begin

                min2 = abs_vals[i];

            end

        end

        // OUTPUT GENERATION

        for (i = 0; i < DEGREE; i++) begin

            sign = overall_sign ^ sign_bits[i];

            if (i == min1_idx)
                val = min2;
            else
                val = min1;

            // Normalized Min-Sum
            // Approximate x0.75:
            // val - (val >> 2)

            attenuated_val = val - (val >> 2);

            if (sign)
                msg_out[i] = -$signed(attenuated_val);
            else
                msg_out[i] =  $signed(attenuated_val);

        end

    end

endmodule
