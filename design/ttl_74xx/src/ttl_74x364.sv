// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x364.md.
// ttl_74x364 - Octal D-type register (same as 74x374).
module ttl_74x364 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] reg_q;
    always_ff @(posedge clk) reg_q <= d;
    assign q = oe_n ? 8'h00 : reg_q;
endmodule
