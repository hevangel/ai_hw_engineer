// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x373.md.
// =============================================================================
// ttl_74x373 - Octal D-type transparent latch, 3-state outputs
//
// When le=1 (high), q follows d (transparent). When le=0, q holds.
// When oe_n=0, outputs are driven; when oe_n=1, outputs are 0 (project
// convention for representing high-Z in FPGA-internal logic).
// =============================================================================

module ttl_74x373 (
    input  logic       oe_n,
    input  logic       le,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] latch_q;

    always_latch begin
        if (le) latch_q = d;
    end

    assign q = oe_n ? 8'h00 : latch_q;
endmodule
