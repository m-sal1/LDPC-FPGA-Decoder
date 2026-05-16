module edge_message_bank #(

    parameter WIDTH      = 8,
    parameter NUM_EDGES  = 2048,
    parameter ADDR_WIDTH = 12

)(

    input logic clk,

    // Read interface
    input  logic read_enable,
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic signed [WIDTH-1:0] read_data,

    // Write interface
    input logic write_enable,
    input logic [ADDR_WIDTH-1:0] write_addr,
    input logic signed [WIDTH-1:0] write_data

);

    // -------------------------------------------------
    // EDGE MESSAGE STORAGE
    // -------------------------------------------------

    (* ramstyle = "M20K" *)
    logic signed [WIDTH-1:0] edge_memory [0:NUM_EDGES-1];

    // -------------------------------------------------
    // SYNCHRONOUS MEMORY ACCESS
    // -------------------------------------------------

    always_ff @(posedge clk) begin

        // Write updated edge message
        if (write_enable)
            edge_memory[write_addr] <= write_data;

        // Read current edge message
        if (read_enable)
            read_data <= edge_memory[read_addr];

    end

endmodule
