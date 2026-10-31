// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2534.md.
// ttl_74x2534 - 8-bit bus interface register, inverting (= 74x534).
module ttl_74x2534 (
    input  logic       clk, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q_n,
    output logic       hiz
);
    logic [7:0] r;
    always_ff @(posedge clk) r <= d;
    assign q_n = oe_n ? 8'b0 : ~r;
    assign hiz = oe_n;
endmodule
