// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x573.md.
// ttl_74x573 - octal D-type transparent latch, 3-state outputs.
module ttl_74x573 (
    input  logic       le, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_latch if (le) r = d;
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
