// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x904.md.
// ttl_74x904 - Hex non-inverting PMOS buffer (MM74C904).
module ttl_74x904 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
