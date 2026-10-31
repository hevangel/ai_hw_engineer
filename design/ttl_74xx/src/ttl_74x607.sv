// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x607.md.
// ttl_74x607 - octal 2-input mux with output latch (glitch-free, OC).
module ttl_74x607 (
    input  logic       sel, le,
    input  logic [7:0] a, b,
    output logic [7:0] y
);
    logic [7:0] mux, latch_r;
    always_comb mux = sel ? b : a;
    always_latch if (le) latch_r = mux;
    assign y = latch_r;
endmodule
