// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x490.md.
// ttl_74x490 - Dual decade counter (same as 74x390).
module ttl_74x490 (
    input  logic [1:0] clk,
    input  logic [1:0] clr,
    output logic [3:0] q0, q1
);
    always_ff @(posedge clk[0] or posedge clr[0]) begin
        if (clr[0])     q0 <= 0;
        else if (q0==9) q0 <= 0;
        else            q0 <= q0 + 1;
    end
    always_ff @(posedge clk[1] or posedge clr[1]) begin
        if (clr[1])     q1 <= 0;
        else if (q1==9) q1 <= 0;
        else            q1 <= q1 + 1;
    end
endmodule
