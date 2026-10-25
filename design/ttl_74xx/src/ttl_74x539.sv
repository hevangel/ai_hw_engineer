// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x539.md.
// ttl_74x539 - dual 2-to-4 line decoder/demultiplexer with 3-state outputs.
module ttl_74x539 (
    input  logic [1:0] a, b,
    input  logic       ga_n, gb_n,
    output logic [3:0] ya_n, yb_n,
    output logic       hiz_a, hiz_b
);
    always_comb begin
        ya_n = 4'b1111;
        if (!ga_n) ya_n[a] = 1'b0;
    end
    always_comb begin
        yb_n = 4'b1111;
        if (!gb_n) yb_n[b] = 1'b0;
    end
    assign hiz_a = ga_n;
    assign hiz_b = gb_n;
endmodule
