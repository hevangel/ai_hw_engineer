// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x515.md.
// ttl_74x515 - programmable mapping decoder.
// 2-to-4 line decoder enabled when 9-bit address matches the programmed pattern.
module ttl_74x515 #(
    parameter logic [8:0] PATTERN = 9'b0
) (
    input  logic [8:0] addr,
    input  logic [1:0] sel,
    input  logic       enable_n,
    output logic [3:0] y_n
);
    logic match_n;
    assign match_n = !((addr == PATTERN) && !enable_n);
    always_comb begin
        y_n = 4'b1111;
        if (!match_n) y_n[sel] = 1'b0;
    end
endmodule
