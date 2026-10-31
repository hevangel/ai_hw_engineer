// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2823.md.
// ttl_74x2823 - 9-bit D-type flip-flop with clear (3-state).
module ttl_74x2823 (
    input  logic        clk, oe_n, clr_n,
    input  logic [8:0]  d,
    output logic [8:0]  q,
    output logic        hiz
);
    logic [8:0] r;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) r <= 9'b0;
        else        r <= d;
    end
    assign q   = oe_n ? 9'b0 : r;
    assign hiz = oe_n;
endmodule
