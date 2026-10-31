// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x432.md.
// ttl_74x432 - 8-bit multi-mode buffered latch.
module ttl_74x432 (
    input  logic       md,
    input  logic       stb,
    input  logic       cs_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;
    always_latch begin
        if (md || stb) latch_q = d;
    end
    assign q = cs_n ? 8'h00 : latch_q;
endmodule
