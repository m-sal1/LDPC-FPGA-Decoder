module decoder_iteration #(

    parameter WIDTH  = 8,
    parameter DEGREE = 8

)(

    input logic signed [WIDTH-1:0] llr_in,

    input logic signed [WIDTH-1:0]
        vn_to_cn [0:DEGREE-1],

    // FIX: Changed from 'input' to 'output' to resolve Error 12012
    // Renamed to 'cn_to_vn_out' to expose the true CNU calculations
    output logic signed [WIDTH-1:0]
        cn_to_vn_out [0:DEGREE-1],

    output logic signed [WIDTH-1:0]
        updated_vn_to_cn [0:DEGREE-1],

    output logic signed [WIDTH-1:0]
        decision_llr

);

    // -------------------------------------------------
    // Internal CNU output
    // -------------------------------------------------

    logic signed [WIDTH-1:0]
        cnu_out [0:DEGREE-1];

    // FIX: Wire the internal CNU messages directly to our new output port
    // so the vn_update_unit in the top level can read them
    assign cn_to_vn_out = cnu_out;

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

endmodule
