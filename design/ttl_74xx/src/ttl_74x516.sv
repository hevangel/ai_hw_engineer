// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x516.md.
// ttl_74x516 - 16-bit multiplier/divider (combinational digital model).
module ttl_74x516 (
    input  logic [15:0] a, b,
    input  logic        mul_div_n,
    output logic [31:0] result
);
    always_comb begin
        if (mul_div_n) result = a * b;
        else           result = (b == 0) ? 32'hFFFFFFFF : {16'd0, a / b};
    end
endmodule
