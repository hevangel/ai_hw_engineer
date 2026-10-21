// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x577.md.
// ttl_74x577 - octal D-FF, synchronous clear, inverting outputs.
module ttl_74x577 (
    input  logic       clk, oe_n, clr_n,
    input  logic [7:0] d,
    output logic [7:0] q_n,
    output logic       hiz
);
    logic [7:0] r;
    always_ff @(posedge clk) begin
        if (!clr_n) r <= 0;
        else        r <= d;
    end
    assign q_n = oe_n ? 8'b0 : ~r;
    assign hiz = oe_n;
endmodule
