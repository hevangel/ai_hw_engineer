// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x378.md.
// ttl_74x378 - 6-bit register with clock enable.
module ttl_74x378 (
    input  logic       clk,
    input  logic       ce_n,
    input  logic [5:0] d,
    output logic [5:0] q
);
    always_ff @(posedge clk) begin
        if (!ce_n) q <= d;
    end
endmodule
