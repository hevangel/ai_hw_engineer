// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x559.md.
// ttl_74x559 - 8-bit expandable two's-complement multiplier/divider.
module ttl_74x559 (
    input  logic signed [7:0] a, b,
    input  logic              mul_div_n,
    output logic signed [15:0] result
);
    always_comb begin
        if (mul_div_n) result = a * b;
        else if (b == 0) result = 16'h7FFF;
        else             result = 16'(a / b);
    end
endmodule
