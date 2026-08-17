// Syndrome checker for verifying the decoded codeword against all parity-check equations.
// Moustafa Salman

module syndrome_checker #(

    parameter NUM_CHECK_NODES = 256,
    parameter MAX_ROW_WEIGHT  = 8,
    parameter VN_WIDTH        = 10

)(

    input logic clk,

    // Hard decision bits from decoder
    input logic [511:0] decoded_bits,

    // Syndrome status
    output logic syndrome_valid

);

    // Each ROM entry contains the variable-node indices connected to one
    // check node. The indices are packed into fixed-width slots.

    logic [VN_WIDTH*MAX_ROW_WEIGHT-1:0]
        check_node_map [0:NUM_CHECK_NODES-1];

    // Loop variables and intermediate parity state.

    integer cn;
    integer vn_idx;
    integer bit_idx;

    logic parity;

    logic all_checks_passed;

    // Load the parity-check connectivity from the generated memory file.

    initial begin

        $readmemb(
            "check_node_map.mem",
            check_node_map
        );

    end

    // Evaluate the syndrome combinationally by XORing the decoded bits
    // connected to each check node. A valid codeword has zero parity for
    // every check equation.

    always_comb begin

        all_checks_passed = 1'b1;

        for (cn = 0; cn < NUM_CHECK_NODES; cn++) begin

            parity = 1'b0;

            // XOR all variable nodes connected to this check node.

            for (bit_idx = 0;
                 bit_idx < MAX_ROW_WEIGHT;
                 bit_idx++) begin

                vn_idx =
                    check_node_map[cn]
                    [bit_idx*VN_WIDTH +: VN_WIDTH];

                parity =
                    parity ^
                    decoded_bits[vn_idx];

            end

            // Any non-zero parity means this check equation failed.

            if (parity != 1'b0)
                all_checks_passed = 1'b0;

        end

        syndrome_valid = all_checks_passed;

    end

endmodule
