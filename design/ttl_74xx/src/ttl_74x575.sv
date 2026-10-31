// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x575.md.
// ttl_74x575 - octal D-type edge-triggered flip-flop, synchronous clear, 3-state.
module ttl_74x575 (
    input  logic       clk, oe_n, clr_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_ff @(posedge clk) begin
        if (!clr_n) r <= 0;
        else        r <= d;
    end
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
