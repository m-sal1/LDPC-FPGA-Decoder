// barrel_shifter.sv
// Performs cyclic message rotation used to route QC-LDPC messages.
// Moustafa Salman

module barrel_shifter #(
    parameter int Z         = 8,
    parameter int MSG_WIDTH = 8
)(
    input  logic signed [MSG_WIDTH-1:0]  data_in  [0:Z-1],
    input  logic [$clog2(Z)-1:0]         shift,
    output logic signed [MSG_WIDTH-1:0]  data_out [0:Z-1]
);
    always_comb begin
        // Apply the requested cyclic rotation to each message position.
        for (int k = 0; k < Z; k++)
            data_out[k] = data_in[(k - int'(shift) + Z) % Z];
    end
endmodule
