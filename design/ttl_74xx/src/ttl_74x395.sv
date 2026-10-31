// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x395.md.
// ttl_74x395 - 4-bit cascadable shift register.
module ttl_74x395 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic       s_l,
    input  logic       din,
    input  logic [3:0] p,
    output logic [3:0] q
);
    logic [3:0] sr;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)  sr <= 4'h0;
        else if (s_l) sr <= p;
        else          sr <= {din, sr[3:1]};
    end
    assign q = oe_n ? 4'h0 : sr;
endmodule
