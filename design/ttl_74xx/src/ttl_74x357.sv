// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x357.md.
// ttl_74x357 - 8-to-1 mux with edge-triggered registers. Same as 74x356.
module ttl_74x357 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [2:0] s,
    input  logic [7:0] d,
    output logic       y
);
    logic [7:0] reg_d;
    always_ff @(posedge clk) reg_d <= d;
    assign y = oe_n ? 1'b0 : reg_d[s];
endmodule
