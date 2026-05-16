module iteration_controller #(

    parameter MAX_ITERATIONS = 10

)(

    input  logic clk,
    input  logic rst,

    input  logic start,

    input  logic syndrome_valid,

    output logic decoding_done,

    output logic iteration_enable,

    output logic [7:0] iteration_count

);

    typedef enum logic [1:0] {

        IDLE,
        RUNNING,
        DONE

    } state_t;

    state_t current_state;
    state_t next_state;

    // -------------------------------------------------
    // STATE REGISTER
    // -------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst)
            current_state <= IDLE;

        else
            current_state <= next_state;

    end

    // -------------------------------------------------
    // ITERATION COUNTER
    // -------------------------------------------------

    always_ff @(posedge clk or posedge rst) begin

        if (rst) begin

            iteration_count <= 0;

        end

        else begin

            if (current_state == IDLE && start)

                iteration_count <= 0;

            else if (current_state == RUNNING)

                iteration_count <= iteration_count + 1;

        end

    end

    // -------------------------------------------------
    // NEXT STATE LOGIC
    // -------------------------------------------------

    always_comb begin

        next_state = current_state;

        case (current_state)

            IDLE: begin

                if (start)
                    next_state = RUNNING;

            end

            RUNNING: begin

                if (syndrome_valid)
                    next_state = DONE;

                else if (iteration_count >= MAX_ITERATIONS)
                    next_state = DONE;

            end

            DONE: begin

                next_state = IDLE;

            end

        endcase

    end

    // -------------------------------------------------
    // OUTPUT LOGIC
    // -------------------------------------------------

    always_comb begin

        decoding_done   = 0;
        iteration_enable = 0;

        case (current_state)

            IDLE: begin

                decoding_done   = 0;
                iteration_enable = 0;

            end

            RUNNING: begin

                decoding_done   = 0;
                iteration_enable = 1;

            end

            DONE: begin

                decoding_done   = 1;
                iteration_enable = 0;

            end

        endcase

    end

endmodule
