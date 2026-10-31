// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x526.md.
// ttl_74x526 - fuse programmable identity comparator, 16-bit.
module ttl_74x526 #(
    parameter logic [15:0] PATTERN = 16'h0000
) (
    input  logic [15:0] p,
    output logic        match
);
    assign match = (p == PATTERN);
endmodule
