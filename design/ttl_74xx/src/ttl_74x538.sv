// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x538.md.
// ttl_74x538 - 3-to-8 line decoder/demultiplexer with 3-state outputs.
module ttl_74x538 (
    input  logic [2:0] a,
    input  logic       g1, g2a_n, g2b_n,
    output logic [7:0] y_n,
    output logic       hiz
);
    logic enable;
    assign enable = g1 && !g2a_n && !g2b_n;
    always_comb begin
        y_n = 8'hFF;
        if (enable) y_n[a] = 1'b0;
    end
    assign hiz = !enable;
endmodule
