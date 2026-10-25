// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x322244.md.
// ttl_74x322244 - 32-bit buffer/driver (= 74x244 widened).
module ttl_74x322244 (
    input  logic        oe_n,
    input  logic [31:0] a,
    output logic [31:0] y,
    output logic        hiz
);
    assign y   = oe_n ? 32'b0 : a;
    assign hiz = oe_n;
endmodule
