// barrel_shifter.sv — Cyclic right shift for QC-LDPC message routing
//
// out[k] = in[(k - shift + Z) % Z]
// Combinational, zero latency.
// Author: Mostafa Salman

module barrel_shifter #(
    parameter int Z         = 8,
    parameter int MSG_WIDTH = 8
)(
    input  logic signed [MSG_WIDTH-1:0]  data_in  [0:Z-1],
    input  logic [$clog2(Z)-1:0]         shift,
    output logic signed [MSG_WIDTH-1:0]  data_out [0:Z-1]
);
    always_comb begin
        for (int k = 0; k < Z; k++)
            data_out[k] = data_in[(k - int'(shift) + Z) % Z];
    end
endmodule
