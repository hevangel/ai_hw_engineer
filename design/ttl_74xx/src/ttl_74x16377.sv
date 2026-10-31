// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16377.md.
// ttl_74x16377 - 16-bit edge-triggered D flip-flop with clock enable. Widebus 377.
module ttl_74x16377 (
    input  logic        clk,
    input  logic        en_n,
    input  logic [15:0] d,
    output logic [15:0] q
);
    always_ff @(posedge clk) begin
        if (!en_n) q <= d;
    end
endmodule
