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

    // -------------------------------------------------
    // Check-node connectivity ROM
    // -------------------------------------------------

    logic [VN_WIDTH*MAX_ROW_WEIGHT-1:0]
        check_node_map [0:NUM_CHECK_NODES-1];

    // -------------------------------------------------
    // Internal signals
    // -------------------------------------------------

    integer cn;
    integer vn_idx;
    integer bit_idx;

    logic parity;

    logic all_checks_passed;

    // -------------------------------------------------
    // ROM Initialization
    // -------------------------------------------------

    initial begin

        $readmemb(
            "check_node_map.mem",
            check_node_map
        );

    end

    // -------------------------------------------------
    // Syndrome Evaluation
    // -------------------------------------------------

    always_comb begin

        all_checks_passed = 1'b1;

        // Evaluate every parity-check equation

        for (cn = 0; cn < NUM_CHECK_NODES; cn++) begin

            parity = 1'b0;

            // XOR all connected VN bits

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

            // Parity-check failed

            if (parity != 1'b0)
                all_checks_passed = 1'b0;

        end

        syndrome_valid = all_checks_passed;

    end

endmodule
