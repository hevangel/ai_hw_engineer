// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x795.md.
// ttl_74x795 - octal buffer, non-inverting, shared enable (3-state).
module ttl_74x795 (
    input  logic [7:0] a,
    input  logic       oe_n,
    output logic [7:0] y
);
    assign y = oe_n ? 8'h00 : a;
endmodule
