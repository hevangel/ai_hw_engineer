// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x375.md.
// ttl_74x375 - Quad bistable latch (same as 74x75).
module ttl_74x375 (
    input  logic [1:0] le,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic [3:0] q_n
);
    logic [3:0] latch_q;
    always_latch begin
        if (le[0]) begin latch_q[0] = d[0]; latch_q[1] = d[1]; end
        if (le[1]) begin latch_q[2] = d[2]; latch_q[3] = d[3]; end
    end
    assign q   = latch_q;
    assign q_n = ~latch_q;
endmodule
