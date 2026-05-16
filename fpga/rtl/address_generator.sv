module address_generator #(

    parameter NUM_EDGES = 4096,
    parameter ADDR_WIDTH = 12

)(

    input  logic clk,
    input  logic rst,

    input  logic enable,

    output logic [ADDR_WIDTH-1:0] edge_addr,

    output logic iteration_done

);

    // Edge traversal counter
    logic [ADDR_WIDTH-1:0] edge_counter;

    // -------------------------------------------------
    // EDGE ADDRESS GENERATION
    // -------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            edge_counter <= 0;

        end

        else if (enable) begin

            if (edge_counter == NUM_EDGES - 1)
                edge_counter <= 0;

            else
                edge_counter <= edge_counter + 1;

        end

    end

    // -------------------------------------------------
    // OUTPUTS
    // -------------------------------------------------

    always_comb begin

        edge_addr = edge_counter;

        if (edge_counter == NUM_EDGES - 1)
            iteration_done = 1;

        else
            iteration_done = 0;

    end

endmodule
