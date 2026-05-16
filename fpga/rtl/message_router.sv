module message_router #(

    parameter WIDTH      = 8,
    parameter DEGREE     = 8,
    parameter VN_WIDTH   = 10,
    parameter CN_WIDTH   = 10

)(

    input logic clk,

    // Graph connectivity
    input logic [VN_WIDTH-1:0] vn_index,
    input logic [CN_WIDTH-1:0] cn_index,

    // Incoming edge message
    input logic signed [WIDTH-1:0] edge_message,

    // Routed decoder inputs
    output logic signed [WIDTH-1:0] vn_to_cn [0:DEGREE-1],
    output logic signed [WIDTH-1:0] cn_to_vn [0:DEGREE-1]

);

    integer i;

    always_comb begin

        // Default clear
        for (i = 0; i < DEGREE; i++) begin

            vn_to_cn[i] = 0;
            cn_to_vn[i] = 0;

        end

        // Temporary routing model
        //
        // Later:
        // - real VN banks
        // - real CN banks
        // - edge scheduling
        // - layered/flooding control
        //
        // For now:
        // route graph-selected edge into datapath

        vn_to_cn[vn_index % DEGREE] = edge_message;

        cn_to_vn[cn_index % DEGREE] = edge_message;

    end

endmodule
