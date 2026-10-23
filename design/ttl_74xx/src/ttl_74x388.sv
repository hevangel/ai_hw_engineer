// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x388.md.
// ttl_74x388 - 4-bit D-type register.
module ttl_74x388 (
    input  logic       clk,
    input  logic [3:0] d,
    output logic [3:0] q
);
    always_ff @(posedge clk) q <= d;
endmodule
