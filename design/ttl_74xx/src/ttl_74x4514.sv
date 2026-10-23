// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4514.md.
// ttl_74x4514 - 4-to-16 line decoder/demultiplexer with input latches.
// le: transparent latch enable; en_n: output enable (low=outputs active).
// Selected line asserts high; others low.  When en_n=1 all outputs are low.
module ttl_74x4514 (
    input  logic        le, en_n,
    input  logic [3:0]  d,
    output logic [15:0] y
);
    logic [3:0] q;
    always_latch if (le) q = d;
    always_comb begin
        y = 16'b0;
        if (!en_n) y[q] = 1'b1;
    end
endmodule
