// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2377.md.
// ttl_74x2377 - 8-bit register with clock enable (= 74x377).
module ttl_74x2377 (
    input  logic       clk,
    input  logic       ce_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) begin
        if (!ce_n) q <= d;
    end
endmodule
