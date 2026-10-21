// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x461.md.
// ttl_74x461 - 8-bit presettable binary counter.
module ttl_74x461 (
    input  logic       clk, clr_n, load_n, ce_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        q <= 0;
        else if (!load_n)  q <= d;
        else if (!ce_n)    q <= q + 1;
    end
endmodule
