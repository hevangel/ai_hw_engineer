// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x568.md.
// ttl_74x568 - decade up/down counter, synchronous, with terminal-count outputs.
module ttl_74x568 (
    input  logic       clk, ce_n, load_n, clr_n, u_d_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       tcu_n, tcd_n
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 0;
        else if (!load_n) q <= d;
        else if (!ce_n) begin
            if (!u_d_n) q <= (q == 4'd9) ? 4'd0 : q + 1;
            else        q <= (q == 4'd0) ? 4'd9 : q - 1;
        end
    end
    assign tcu_n = !((q == 4'd9) && !ce_n && !u_d_n);
    assign tcd_n = !((q == 4'd0) && !ce_n &&  u_d_n);
endmodule
