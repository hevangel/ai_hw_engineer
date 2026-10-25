// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162245.md.
// ttl_74x162245 - 16-bit bus transceiver (3-state). Widebus 74x245.
module ttl_74x162245 (
    input  logic        oe_n,
    input  logic        dir,
    input  logic [15:0] a_in,
    input  logic [15:0] b_in,
    output logic [15:0] a_out,
    output logic [15:0] b_out,
    output logic        a_oe_n,
    output logic        b_oe_n
);
    always_comb begin
        if (oe_n) begin
            a_out  = 16'h0000; b_out  = 16'h0000;
            a_oe_n = 1'b1;     b_oe_n = 1'b1;
        end else if (dir) begin
            a_out  = 16'h0000; b_out  = a_in;
            a_oe_n = 1'b1;     b_oe_n = 1'b0;
        end else begin
            a_out  = b_in;     b_out  = 16'h0000;
            a_oe_n = 1'b0;     b_oe_n = 1'b1;
        end
    end
endmodule
