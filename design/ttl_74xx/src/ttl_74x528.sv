// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x528.md.
// ttl_74x528 - fuse programmable identity comparator, 12-bit.
module ttl_74x528 #(
    parameter logic [11:0] PATTERN = 12'h000
) (
    input  logic [11:0] p,
    output logic        match
);
    assign match = (p == PATTERN);
endmodule
