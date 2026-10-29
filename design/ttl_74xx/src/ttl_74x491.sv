// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x491.md.
// ttl_74x491 - 10-bit binary up/down counter with limited preset.
module ttl_74x491 (
    input  logic       clk, clr_n, u_d_n,
    input  logic       set_msb_n,    // limited preset: when low, set high bit
    output logic [9:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)         q <= 0;
        else if (!set_msb_n) q[9] <= 1;
        else if (!u_d_n)    q <= q + 1;
        else                q <= q - 1;
    end
endmodule
