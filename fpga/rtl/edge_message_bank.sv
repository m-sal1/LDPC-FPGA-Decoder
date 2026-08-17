// Stores one message value for each edge in the Tanner graph.
// Provides synchronous read and write access and maps the memory to M20K blocks.
// Moustafa Salman

module edge_message_bank #(

    parameter WIDTH      = 8,
    parameter NUM_EDGES  = 2048,
    parameter ADDR_WIDTH = 12

)(

    input logic clk,

    // Read interface
    input logic read_enable,
    input logic [ADDR_WIDTH-1:0] read_addr,
    output logic signed [WIDTH-1:0] read_data,

    // Write interface
    input logic write_enable,
    input logic [ADDR_WIDTH-1:0] write_addr,
    input logic signed [WIDTH-1:0] write_data

);

    // Stores the message associated with each edge.

    (* ramstyle = "M20K" *)
    logic signed [WIDTH-1:0] edge_memory [0:NUM_EDGES-1];

    // Both memory operations are synchronous to the rising clock edge.

    always_ff @(posedge clk) begin

        // Write an updated edge message.
        if (write_enable)
            edge_memory[write_addr] <= write_data;

        // Register the message read from the selected edge.
        if (read_enable)
            read_data <= edge_memory[read_addr];

    end

endmodule
