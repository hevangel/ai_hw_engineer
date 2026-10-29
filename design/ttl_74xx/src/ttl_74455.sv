// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74455.md.
// ttl_74455 - Dual binary up/down counter, synchronous, preset.
module ttl_74455 (
    input  logic [1:0] clk,
    input  logic [1:0] load_n,
    input  logic [1:0] u_d_n,
    input  logic [3:0] d0, d1,
    output logic [3:0] q0, q1
);
    always_ff @(posedge clk[0]) begin
        if (!load_n[0])      q0 <= d0;
        else if (!u_d_n[0])  q0 <= q0 + 1;
        else                 q0 <= q0 - 1;
    end
    always_ff @(posedge clk[1]) begin
        if (!load_n[1])      q1 <= d1;
        else if (!u_d_n[1])  q1 <= q1 + 1;
        else                 q1 <= q1 - 1;
    end
endmodule
