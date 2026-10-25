// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2253.md.
// =============================================================================
// ttl_74x2253 - Dual 4-line to 1-line multiplexer, 3-state outputs
//
// Original part number : 74x2253 (e.g. 74F2253)
// Description          : Dual 4-to-1 multiplexer with 3-state outputs and
//                        on-chip series (25-ohm) output-damping resistors.
// Datasheet reference  : logically identical to the 'x253.
//
// Function
// --------
// Logically identical to the [ttl_74x253]: two independent 4-to-1 multiplexers
// share the 2-bit select s; each has its own active-low output enable g_n[i].
//
//     y[0] = g_n[0] ? 0 : d0[s]
//     y[1] = g_n[1] ? 0 : d1[s]
//
// The only difference from the '253 is the on-chip series-damping resistors on
// the outputs (a bus-driving / signal-integrity feature) — an electrical-only
// property that is not modeled. High-Z is modeled as a driven 0 per library
// convention.
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

module ttl_74x2253 (
    input  logic [1:0] s,
    input  logic [1:0] g_n,
    input  logic [3:0] d0,
    input  logic [3:0] d1,
    output logic [1:0] y
);
    assign y[0] = g_n[0] ? 1'b0 : d0[s];
    assign y[1] = g_n[1] ? 1'b0 : d1[s];
endmodule
