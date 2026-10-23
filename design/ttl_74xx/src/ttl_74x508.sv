// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x508.md.
// ttl_74x508 - 8x8 multiplier/divider (combinational digital model).
module ttl_74x508 (
    input  logic [7:0] a, b,
    input  logic       mul_div_n, // 1=multiply, 0=divide
    output logic [15:0] result
);
    always_comb begin
        if (mul_div_n) result = a * b;
        else           result = (b == 0) ? 16'hFFFF : {8'd0, a / b[7:0]};
    end
endmodule
