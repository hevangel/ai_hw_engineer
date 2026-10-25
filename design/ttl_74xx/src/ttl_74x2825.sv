// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2825.md.
// ttl_74x2825 - 8-bit D-type flip-flop with clear and clock enable (3-state).
module ttl_74x2825 (
    input  logic        clk, oe_n, clr_n, ce_n,
    input  logic [7:0]  d,
    output logic [7:0]  q,
    output logic        hiz
);
    logic [7:0] r;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)    r <= 8'b0;
        else if (!ce_n) r <= d;
    end
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
