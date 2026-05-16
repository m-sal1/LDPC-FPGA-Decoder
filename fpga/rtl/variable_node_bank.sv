module variable_node_bank #(

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

    output logic signed [WIDTH-1:0] read_data,

    // Full decoded bit output
    output logic [NUM_VARIABLES-1:0] decoded_bits

);

    // -------------------------------------------------
    // Variable-node belief storage
    // -------------------------------------------------

    (* ramstyle = "M20K" *)
    logic signed [WIDTH-1:0]
        vn_memory [0:NUM_VARIABLES-1];

    integer i;

    // -------------------------------------------------
    // VN memory access
    // -------------------------------------------------

    always_ff @(posedge clk) begin

        // Write updated VN belief
        if (write_enable)
            vn_memory[write_addr] <= write_data;

        // Read VN belief
        if (read_enable)
            read_data <= vn_memory[read_addr];

    end

    // -------------------------------------------------
    // Hard decision generation
    // -------------------------------------------------

    always_comb begin

        for (i = 0; i < NUM_VARIABLES; i++) begin

            if (vn_memory[i] < 0)
                decoded_bits[i] = 1'b1;
            else
                decoded_bits[i] = 1'b0;

        end

    end

endmodule
