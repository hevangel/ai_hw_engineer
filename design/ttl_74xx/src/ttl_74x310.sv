// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x310.md.
// ttl_74x310 - Octal inverting buffer with 3-state outputs.
module ttl_74x310 (
    input  logic [7:0] a,
    input  logic       oe_n,
    output logic [7:0] y
);
    assign y = oe_n ? 8'h00 : ~a;
endmodule
