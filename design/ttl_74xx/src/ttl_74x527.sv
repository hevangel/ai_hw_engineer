// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x527.md.
// ttl_74x527 - fuse programmable identity comparator, 8-bit fuse + 4-bit conventional.
module ttl_74x527 #(
    parameter logic [7:0] PATTERN = 8'h00
) (
    input  logic [7:0] p,
    input  logic [3:0] q,
    input  logic [3:0] qref,
    output logic       match
);
    assign match = (p == PATTERN) && (q == qref);
endmodule
