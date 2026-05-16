module decoder_iteration #(

    parameter WIDTH  = 8,
    parameter DEGREE = 8

)(

    input  logic signed [WIDTH-1:0] llr_in,

    input  logic signed [WIDTH-1:0] vn_to_cn [0:DEGREE-1],

    output logic signed [WIDTH-1:0] cn_to_vn [0:DEGREE-1],

    output logic signed [WIDTH-1:0] updated_vn_to_cn [0:DEGREE-1],

    output logic signed [WIDTH-1:0] decision_llr

);

    // Internal wires between CNU and VNU
    logic signed [WIDTH-1:0] cnu_out [0:DEGREE-1];

    // -------------------------------------------------
    // CHECK NODE UNIT
    // -------------------------------------------------

    cnu #(
        .DEGREE(DEGREE),
        .WIDTH(WIDTH)
    ) cnu_inst (

        .msg_in(vn_to_cn),

        .msg_out(cnu_out)

    );

    // -------------------------------------------------
    // VARIABLE NODE UNIT
    // -------------------------------------------------

    vnu #(
        .DEGREE(DEGREE),
        .WIDTH(WIDTH)
    ) vnu_inst (

        .llr_in(llr_in),

        .msg_in(cnu_out),

        .msg_out(updated_vn_to_cn),

        .decision_llr(decision_llr)

    );

    // Optional external visibility
    assign cn_to_vn = cnu_out;

endmodule
