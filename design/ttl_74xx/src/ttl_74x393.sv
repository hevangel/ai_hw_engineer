// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x393.md.
// ttl_74x393 - Dual 4-bit binary counter, async clear.
module ttl_74x393 (
    input  logic [1:0] clk,
    input  logic [1:0] clr,        // active high
    output logic [3:0] q0,
    output logic [3:0] q1
);
    always_ff @(negedge clk[0] or posedge clr[0]) begin
        if (clr[0]) q0 <= 4'h0;
        else        q0 <= q0 + 4'h1;
    end
    always_ff @(negedge clk[1] or posedge clr[1]) begin
        if (clr[1]) q1 <= 4'h0;
        else        q1 <= q1 + 4'h1;
    end
endmodule
