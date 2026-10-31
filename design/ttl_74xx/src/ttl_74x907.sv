// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x907.md.
// ttl_74x907 - Hex open-drain p-channel buffer (MM74C907).
// Logically equivalent to ttl_74x906; p-channel drive style is doc-only.
module ttl_74x907 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
