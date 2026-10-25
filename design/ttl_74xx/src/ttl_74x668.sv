// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x668.md.
// ttl_74x668 - synchronous presettable 4-bit BCD decade up/down counter.
//
// Behaviorally equivalent to 74x168: posedge clock, synchronous load on
// load_n=0, count enabled while enp & ent are both high, direction selected
// by u_d_n (1=up, 0=down), decade modulus (counts 0..9), RCO active-low at
// terminal count gated by ent.
module ttl_74x668 (
    input  logic       clk,
    input  logic       load_n,
    input  logic       u_d_n,
    input  logic       enp,
    input  logic       ent,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       rco_n
);
    always_ff @(posedge clk) begin
        if (!load_n)        q <= d;
        else if (enp & ent) begin
            if (u_d_n) begin
                if (q == 4'd9) q <= 4'd0;
                else           q <= q + 4'd1;
            end else begin
                if (q == 4'd0) q <= 4'd9;
                else           q <= q - 4'd1;
            end
        end
    end
    assign rco_n = ~(((u_d_n && q == 4'd9) || (!u_d_n && q == 4'd0)) && ent);
endmodule
