// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x482.md.
// ttl_74x482 - 4-bit slice control element. Simplified register + status flags.
module ttl_74x482 (
    input  logic       clk, clr_n,
    input  logic [3:0] din,
    input  logic       ce_n,
    output logic [3:0] q,
    output logic       zero,
    output logic       neg
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)     q <= 0;
        else if (!ce_n) q <= din;
    end
    assign zero = (q == 0);
    assign neg  = q[3];
endmodule
