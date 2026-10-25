// ASSUMPTION: Z is represented by per-output drive flags; data is masked to zero.
module ttl_74x162344 (
    input  logic [7:0]  a,
    input  logic [3:0]  oe_n,
    output logic [31:0] b,
    output logic [31:0] drive
);
    for (genvar output_index = 0; output_index < 32; output_index++) begin : g_output
        localparam integer ADDRESS_INDEX = output_index / 4;
        localparam integer OE_INDEX = ADDRESS_INDEX / 2;

        always_comb begin
            drive[output_index] = !oe_n[OE_INDEX];
            b[output_index] = drive[output_index] ? a[ADDRESS_INDEX] : 1'b0;
        end
    end
endmodule
