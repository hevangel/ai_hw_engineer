// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x560.md.
// ttl_74x560 - 4-bit decade counter (synchronous loadable).
module ttl_74x560 (
    input  logic       clk, ce_n, load_n, clr_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       tc
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 0;
        else if (!load_n) q <= d;
        else if (!ce_n)   q <= (q == 4'd9) ? 4'd0 : q + 1;
    end
    assign tc = (q == 4'd9) && !ce_n;
endmodule
