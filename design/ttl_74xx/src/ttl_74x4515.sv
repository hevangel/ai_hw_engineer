// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4515.md.
// ttl_74x4515 - 4-to-16 line decoder/demultiplexer with input latches,
// inverting outputs (selected line low, others high; en_n=1 forces all high).
module ttl_74x4515 (
    input  logic        le, en_n,
    input  logic [3:0]  d,
    output logic [15:0] y_n
);
    logic [3:0] q;
    always_latch if (le) q = d;
    always_comb begin
        y_n = 16'hFFFF;
        if (!en_n) y_n[q] = 1'b0;
    end
endmodule
