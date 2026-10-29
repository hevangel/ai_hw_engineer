// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x377.md.
// ttl_74x377 - 8-bit register with clock enable.
module ttl_74x377 (
    input  logic       clk,
    input  logic       ce_n,         // active-low clock enable
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) begin
        if (!ce_n) q <= d;
    end
endmodule
