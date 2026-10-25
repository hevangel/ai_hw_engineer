// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2257.md.
// =============================================================================
// ttl_74x2257 - Quad 2-line to 1-line multiplexer, non-inverting, 3-state
//
// Original part number : 74x2257 (e.g. 74F2257)
// Description          : Quad 2-to-1 multiplexer, 3-state outputs, with on-chip
//                        series (25-ohm) output-damping resistors.
// Datasheet reference  : logically identical to the 'x257.
//
// Function
// --------
// Logically identical to the [ttl_74x257]: four 2-to-1 muxes share a common
// select and an active-low output enable.
//
//     y = g_n ? 0 : (select ? b : a)
//
// The only difference from the '257 is the on-chip series-damping resistors on
// the outputs — an electrical-only property that is not modeled. High-Z is
// modeled as a driven 0 per library convention.
//
// FPGA notes
// ----------
// Pure combinational. No clock/reset.
//
// Unsupported physical behavior
// -----------------------------
// On-chip series output-damping resistors (electrical only). True three-state
// high-Z is modeled as a driven 0.
// =============================================================================

module ttl_74x2257 (
    input  logic       g_n,
    input  logic       select,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] y
);
    assign y = g_n ? 4'h0 : (select ? b : a);
endmodule
