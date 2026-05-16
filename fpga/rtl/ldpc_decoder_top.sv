module ldpc_decoder_top #(

    parameter WIDTH              = 8,
    parameter DEGREE             = 8,
    parameter NUM_EDGES          = 4096,
    parameter ADDR_WIDTH         = 12,
    parameter MAX_ITERATIONS     = 10,
    parameter CODEWORD_BITS      = 512,
    parameter VN_ADDR_WIDTH      = 9

)(

    input logic clk,
    input logic rst,

    input logic start,

    input logic signed [WIDTH-1:0] llr_in,

    output logic decoding_done,

    output logic signed [WIDTH-1:0] decision_llr

);

    // -------------------------------------------------
    // Controller Signals
    // -------------------------------------------------

    logic iteration_enable;

    logic [7:0] iteration_count;

    logic syndrome_valid;

    // -------------------------------------------------
    // Address Generator Signals
    // -------------------------------------------------

    logic [ADDR_WIDTH-1:0] edge_addr;

    logic iteration_done;

    // -------------------------------------------------
    // Edge ROM Signals
    // -------------------------------------------------

    logic [9:0] vn_index;

    logic [9:0] cn_index;

    // -------------------------------------------------
    // Edge Message Bank Signals
    // -------------------------------------------------

    logic mem_we;

    logic mem_re;

    logic signed [WIDTH-1:0] mem_read_data;

    logic signed [WIDTH-1:0] mem_write_data;

    logic [ADDR_WIDTH-1:0] mem_write_addr;

    // -------------------------------------------------
    // Variable Node Bank Signals
    // -------------------------------------------------

    logic vn_write_enable;

    logic vn_read_enable;

    logic signed [WIDTH-1:0] vn_read_data;

    logic [CODEWORD_BITS-1:0] decoded_bits;

    logic signed [WIDTH-1:0] vn_belief;

    // -------------------------------------------------
    // Decoder Routing Signals
    // -------------------------------------------------

    logic signed [WIDTH-1:0]
        vn_to_cn [0:DEGREE-1];

    logic signed [WIDTH-1:0]
        routed_cn_to_vn [0:DEGREE-1];

    logic signed [WIDTH-1:0]
        updated_vn_to_cn [0:DEGREE-1];

    // FIX: Added new wire to carry the TRUE Check Node messages
    logic signed [WIDTH-1:0]
        true_cn_to_vn [0:DEGREE-1];

    // -------------------------------------------------
    // Iteration Controller
    // -------------------------------------------------

    iteration_controller #(

        .MAX_ITERATIONS(MAX_ITERATIONS)

    ) controller_inst (

        .clk(clk),
        .rst(rst),

        .start(start),

        .syndrome_valid(syndrome_valid),

        .decoding_done(decoding_done),

        .iteration_enable(iteration_enable),

        .iteration_count(iteration_count)

    );

    // -------------------------------------------------
    // Address Generator
    // -------------------------------------------------

    address_generator #(

        .NUM_EDGES(NUM_EDGES),
        .ADDR_WIDTH(ADDR_WIDTH)

    ) addr_gen_inst (

        .clk(clk),
        .rst(rst),

        .enable(iteration_enable),

        .edge_addr(edge_addr),

        .iteration_done(iteration_done)

    );

    // -------------------------------------------------
    // Edge ROM
    // -------------------------------------------------

    edge_rom edge_rom_inst (

        .clk(clk),

        .edge_addr(edge_addr),

        .vn_index(vn_index),

        .cn_index(cn_index)

    );

    // -------------------------------------------------
    // Edge Message Bank
    // -------------------------------------------------

    edge_message_bank #(

        .WIDTH(WIDTH),
        .NUM_EDGES(NUM_EDGES),
        .ADDR_WIDTH(ADDR_WIDTH)

    ) edge_bank_inst (

        .clk(clk),

        .read_enable(mem_re),

        .read_addr(edge_addr),

        .read_data(mem_read_data),

        .write_enable(mem_we),

        .write_addr(mem_write_addr),

        .write_data(mem_write_data)

    );

    // -------------------------------------------------
    // Variable Node Bank
    // -------------------------------------------------

    variable_node_bank #(

        .WIDTH(WIDTH),
        .NUM_VARIABLES(CODEWORD_BITS),
        .ADDR_WIDTH(VN_ADDR_WIDTH)

    ) vn_bank_inst (

        .clk(clk),

        .write_enable(vn_write_enable),

        .write_addr(vn_index[VN_ADDR_WIDTH-1:0]),

        .write_data(vn_belief),

        .read_enable(vn_read_enable),

        .read_addr(vn_index[VN_ADDR_WIDTH-1:0]),

        .read_data(vn_read_data),

        .decoded_bits(decoded_bits)

    );

    // -------------------------------------------------
    // Message Router
    // -------------------------------------------------

    message_router #(

        .WIDTH(WIDTH),
        .DEGREE(DEGREE)

    ) router_inst (

        .clk(clk),

        .vn_index(vn_index),

        .cn_index(cn_index),

        .edge_message(mem_read_data),

        .vn_to_cn(vn_to_cn),

        .cn_to_vn(routed_cn_to_vn)

    );

    // -------------------------------------------------
    // Decoder Iteration Engine
    // -------------------------------------------------

    decoder_iteration #(

        .WIDTH(WIDTH),
        .DEGREE(DEGREE)

    ) iteration_inst (

        .llr_in(llr_in),

        .vn_to_cn(vn_to_cn),

        // FIX: Connect the new output port to our new true message wire
        .cn_to_vn_out(true_cn_to_vn),

        .updated_vn_to_cn(updated_vn_to_cn),

        .decision_llr(decision_llr)

    );

    // -------------------------------------------------
    // VN Update Unit
    // -------------------------------------------------

    vn_update_unit #(

        .WIDTH(WIDTH),
        .DEGREE(DEGREE)

    ) vn_update_inst (

        .llr_in(llr_in),

        // FIX: Feed the TRUE check node messages into the belief accumulator
        .cn_to_vn(true_cn_to_vn),

        .vn_belief(vn_belief)

    );

    // -------------------------------------------------
    // Edge Update Scheduler
    // -------------------------------------------------

    edge_update_scheduler #(

        .WIDTH(WIDTH),
        .DEGREE(DEGREE),
        .ADDR_WIDTH(ADDR_WIDTH)

    ) scheduler_inst (

        .clk(clk),

        .edge_addr(edge_addr),

        .updated_messages(updated_vn_to_cn),

        .write_enable(mem_we),

        .write_addr(mem_write_addr),

        .write_data(mem_write_data)

    );

    // -------------------------------------------------
    // Syndrome Checker
    // -------------------------------------------------

    syndrome_checker syndrome_checker_inst (

        .clk(clk),

        .decoded_bits(decoded_bits),

        .syndrome_valid(syndrome_valid)

    );

    // -------------------------------------------------
    // Variable Node Bank Control
    // -------------------------------------------------

    assign vn_write_enable = iteration_enable;

    assign vn_read_enable  = iteration_enable;

    // -------------------------------------------------
    // Memory Read Control
    // -------------------------------------------------

    assign mem_re = iteration_enable;

endmodule
