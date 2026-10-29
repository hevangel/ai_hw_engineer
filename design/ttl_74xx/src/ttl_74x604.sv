// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x604.md.
// ttl_74x604 - octal 2-input multiplexer with output latch (high-speed).
module ttl_74x604 (
    input  logic       sel, le, oe_n,
    input  logic [7:0] a, b,
    output logic [7:0] y,
    output logic       hiz
);
    logic [7:0] mux, latch_r;
    always_comb mux = sel ? b : a;
    always_latch if (le) latch_r = mux;
    assign y   = oe_n ? 8'b0 : latch_r;
    assign hiz = oe_n;
endmodule
