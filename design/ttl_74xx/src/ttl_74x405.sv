// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x405.md.
// ttl_74x405 - 3-to-8 decoder (Intel 8205 equivalent), active-low outputs.
module ttl_74x405 (
    input  logic [2:0] a,
    input  logic       g1_n, g2_n, g3,
    output logic [7:0] y_n
);
    logic enable;
    assign enable = !g1_n && !g2_n && g3;
    always_comb begin
        y_n = 8'hFF;
        if (enable) y_n[a] = 1'b0;
    end
endmodule
