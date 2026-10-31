// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x669.md.
// ttl_74x669 - synchronous presettable 4-bit binary up/down counter.
//
// Binary (mod-16) twin of ttl_74x668; logically identical to ttl_74x169.
module ttl_74x669 (
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
            if (u_d_n) q <= q + 4'd1;
            else       q <= q - 4'd1;
        end
    end
    assign rco_n = ~(((u_d_n && q == 4'hF) || (!u_d_n && q == 4'h0)) && ent);
endmodule
