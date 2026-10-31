// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x933.md.
// ttl_74x933 - 7-bit address bus comparator. Asserts y=1 when the 7-bit
// expected and observed buses match exactly.
module ttl_74x933 (
    input  logic [6:0] expected,
    input  logic [6:0] address,
    output logic       match
);
    assign match = (expected == address);
endmodule
