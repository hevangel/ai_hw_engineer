// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x803.md.
// ttl_74x803 - quad D flip-flops with matched propagation delays (posedge clock).
module ttl_74x803 (
    input  logic       clk,
    input  logic [3:0] d,
    output logic [3:0] q
);
    always_ff @(posedge clk) q <= d;
endmodule
