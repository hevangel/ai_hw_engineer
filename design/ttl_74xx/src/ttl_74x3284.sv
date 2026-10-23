// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x3284.md.
// ttl_74x3284 - 18-bit synchronous datapath multiplexer.
// 2-to-1 mux per bit with a clocked output register and 3-state enable.
module ttl_74x3284 (
    input  logic        clk, oe_n, sel,
    input  logic [17:0] a, b,
    output logic [17:0] y,
    output logic        hiz
);
    logic [17:0] r;
    always_ff @(posedge clk) r <= sel ? b : a;
    assign y   = oe_n ? 18'b0 : r;
    assign hiz = oe_n;
endmodule
