// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x454.md.
// ttl_74x454 - Dual decade up/down counter, synchronous, preset.
module ttl_74x454 (
    input  logic [1:0] clk,
    input  logic [1:0] load_n,
    input  logic [1:0] u_d_n,         // 1=down, 0=up
    input  logic [3:0] d0, d1,
    output logic [3:0] q0, q1
);
    always_ff @(posedge clk[0]) begin
        if (!load_n[0])      q0 <= d0;
        else if (!u_d_n[0]) begin
            if (q0 == 9) q0 <= 0;
            else         q0 <= q0 + 1;
        end else begin
            if (q0 == 0) q0 <= 9;
            else         q0 <= q0 - 1;
        end
    end
    always_ff @(posedge clk[1]) begin
        if (!load_n[1])      q1 <= d1;
        else if (!u_d_n[1]) begin
            if (q1 == 9) q1 <= 0;
            else         q1 <= q1 + 1;
        end else begin
            if (q1 == 0) q1 <= 9;
            else         q1 <= q1 - 1;
        end
    end
endmodule
