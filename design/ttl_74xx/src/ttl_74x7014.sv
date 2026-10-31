// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7014.md.
// ttl_74x7014 - Hex buffer gate.
module ttl_74x7014 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
