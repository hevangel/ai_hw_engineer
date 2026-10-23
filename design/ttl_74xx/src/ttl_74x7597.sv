// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7597.md.
// ttl_74x7597 - 8-bit shift register with input latches.
// Parallel data is captured into an input latch (transparent when le=1),
// and serially shifted out through `q_out` on each posedge of `clk` when
// `sh_en_n` is low.  When sh_en_n is high, the shift register is reloaded
// from the input latch on every clock.
module ttl_74x7597 (
    input  logic       clk, le, sh_en_n,
    input  logic [7:0] d,
    output logic       q_out
);
    logic [7:0] latch_q;
    logic [7:0] sr;

    always_latch if (le) latch_q = d;

    always_ff @(posedge clk) begin
        if (!sh_en_n) sr <= {sr[6:0], 1'b0};
        else          sr <= latch_q;
    end

    assign q_out = sr[7];
endmodule
