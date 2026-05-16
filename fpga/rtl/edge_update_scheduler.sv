module edge_update_scheduler #(

    parameter WIDTH      = 8,
    parameter DEGREE     = 8,
    parameter ADDR_WIDTH = 12

)(

    input logic clk,

    // Current edge address
    input logic [ADDR_WIDTH-1:0] edge_addr,

    // Updated edge messages from decoder
    input logic signed [WIDTH-1:0] updated_messages [0:DEGREE-1],

    // Selected edge writeback
    output logic write_enable,

    output logic [ADDR_WIDTH-1:0] write_addr,

    output logic signed [WIDTH-1:0] write_data

);

    always_comb begin

        // -------------------------------------------------
        // Temporary Sequential Edge Writeback
        // -------------------------------------------------
        //
        // Later:
        // - layered scheduling
        // - multi-edge issue
        // - bank conflict handling
        // - parallel VN/CN updates
        //
        // For now:
        // sequentially feed updated messages
        // back into edge memory.
        // -------------------------------------------------

        write_enable = 1'b1;

        write_addr = edge_addr;

        write_data = updated_messages[edge_addr % DEGREE];

    end

endmodule
