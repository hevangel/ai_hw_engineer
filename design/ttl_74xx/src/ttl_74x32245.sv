// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x32245.md.
// ttl_74x32245 - 36-bit bus transceiver (3-state). Wider variant of 74x245.
//
// Per the Wikipedia description this part is 36 bits wide. Modeled here as
// 36-bit A/B with shared dir + /OE; if a deployment uses a different width
// or split-enable variant, regenerate from the specific datasheet.
module ttl_74x32245 (
    input  logic        oe_n,
    input  logic        dir,
    input  logic [35:0] a_in,
    input  logic [35:0] b_in,
    output logic [35:0] a_out,
    output logic [35:0] b_out,
    output logic        a_oe_n,
    output logic        b_oe_n
);
    always_comb begin
        if (oe_n) begin
            a_out  = '0;     b_out  = '0;
            a_oe_n = 1'b1;   b_oe_n = 1'b1;
        end else if (dir) begin
            a_out  = '0;     b_out  = a_in;
            a_oe_n = 1'b1;   b_oe_n = 1'b0;
        end else begin
            a_out  = b_in;   b_out  = '0;
            a_oe_n = 1'b0;   b_oe_n = 1'b1;
        end
    end
endmodule
