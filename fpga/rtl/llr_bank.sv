// LLR memory bank used to store channel log-likelihood ratios for each variable node.
// Moustafa Salman

module llr_bank #(

    parameter WIDTH         = 8,
    parameter NUM_VARIABLES = 512,
    parameter ADDR_WIDTH    = 9

)(

    input logic clk,

    // Write interface

    input logic write_enable,

    input logic [ADDR_WIDTH-1:0] write_addr,

    input logic signed [WIDTH-1:0] write_data,

    // Read interface

    input logic read_enable,

    input logic [ADDR_WIDTH-1:0] read_addr,

    output logic signed [WIDTH-1:0] read_data

);

    // Stores one signed LLR value for each variable node.

    logic signed [WIDTH-1:0]
        llr_mem [0:NUM_VARIABLES-1];

    // Synchronous memory operations. Both reads and writes occur on
    // the rising edge of the clock.

    always_ff @(posedge clk) begin

        if (write_enable)

            llr_mem[write_addr]
                <= write_data;

        if (read_enable)

            read_data
                <= llr_mem[read_addr];

    end

endmodule
