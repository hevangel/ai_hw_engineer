// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x569.md.
// ttl_74x569 - binary up/down counter, synchronous, 4-bit.
module ttl_74x569 (
    input  logic       clk, ce_n, load_n, clr_n, u_d_n,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       tcu_n, tcd_n
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 0;
        else if (!load_n) q <= d;
        else if (!ce_n) begin
            if (!u_d_n) q <= q + 1;
            else        q <= q - 1;
        end
    end
    assign tcu_n = !((&q) && !ce_n && !u_d_n);
    assign tcd_n = !((q == 4'd0) && !ce_n && u_d_n);
endmodule
