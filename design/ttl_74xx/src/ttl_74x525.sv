// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x525.md.
// ttl_74x525 - 16-bit programmable counter.
module ttl_74x525 (
    input  logic        clk, load_n, ce_n, clr_n,
    input  logic [15:0] d,
    output logic [15:0] q,
    output logic        tc
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 0;
        else if (!load_n) q <= d;
        else if (!ce_n)   q <= q + 1;
    end
    assign tc = &q & ~ce_n;
endmodule
