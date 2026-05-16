module vn_update_unit #(

    parameter WIDTH  = 8,
    parameter DEGREE = 8

)(

    input logic signed [WIDTH-1:0] llr_in,

    input logic signed [WIDTH-1:0]
        cn_to_vn [0:DEGREE-1],

    output logic signed [WIDTH-1:0]
        vn_belief

);

    integer i;

    logic signed [WIDTH+4:0] accumulation;

    // -------------------------------------------------
    // VN belief accumulation
    // -------------------------------------------------

    always_comb begin

        accumulation = llr_in;

        for (i = 0; i < DEGREE; i++) begin

            accumulation =
                accumulation +
                cn_to_vn[i];

        end

        // Simple saturation

        if (accumulation > 127)
            vn_belief = 127;

        else if (accumulation < -128)
            vn_belief = -128;

        else
            vn_belief = accumulation[WIDTH-1:0];

    end

endmodule
