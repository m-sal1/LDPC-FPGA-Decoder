module message_memory #(

    parameter WIDTH = 8,
    parameter DEPTH = 4096,
    parameter ADDR_WIDTH = $clog2(DEPTH)

)(

    input  logic clk,

    // Write port
    input  logic we,
    input  logic [ADDR_WIDTH-1:0] write_addr,
    input  logic signed [WIDTH-1:0] write_data,

    // Read port
    input  logic re,
    input  logic [ADDR_WIDTH-1:0] read_addr,
    output logic signed [WIDTH-1:0] read_data

);

    // FPGA block RAM inference
    (* ramstyle = "M20K" *)
    logic signed [WIDTH-1:0] memory [0:DEPTH-1];

    // SYNCHRONOUS READ/WRITE

    always_ff @(posedge clk) begin

        // Write operation
        if (we)
            memory[write_addr] <= write_data;

        // Synchronous read
        if (re)
            read_data <= memory[read_addr];

    end

endmodule
