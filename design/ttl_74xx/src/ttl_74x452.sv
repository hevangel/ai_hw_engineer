// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x452.md.
// ttl_74x452 - Dual decade counter, synchronous.
module ttl_74x452 (
    input  logic [1:0] clk,
    input  logic [1:0] clr_n,
    output logic [3:0] q0,
    output logic [3:0] q1
);
    always_ff @(posedge clk[0] or negedge clr_n[0]) begin
        if (!clr_n[0])     q0 <= 0;
        else if (q0 == 9)  q0 <= 0;
        else               q0 <= q0 + 1;
    end
    always_ff @(posedge clk[1] or negedge clr_n[1]) begin
        if (!clr_n[1])     q1 <= 0;
        else if (q1 == 9)  q1 <= 0;
        else               q1 <= q1 + 1;
    end
endmodule
