// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74418.md.
// ttl_74418 - Modulo-16 counter with preload and clear.
module ttl_74418 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic [3:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 4'h0;
        else if (!load_n) q <= d;
        else              q <= q + 4'h1;
    end
endmodule
