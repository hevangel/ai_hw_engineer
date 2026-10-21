// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7007.md.
// ttl_74x7007 - Hex buffer gate (non-inverting).
module ttl_74x7007 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
