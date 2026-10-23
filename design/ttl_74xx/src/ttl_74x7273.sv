// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7273.md.
// ttl_74x7273 - Octal positive-edge-triggered D-FF with reset (= 74x273).
module ttl_74x7273 (
    input  logic       clk, clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'b0;
        else        q <= d;
    end
endmodule
