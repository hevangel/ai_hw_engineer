// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2273.md.
// ttl_74x2273 - Octal D flop with async clear (= 74x273).
module ttl_74x2273 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'h00;
        else        q <= d;
    end
endmodule
