// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x60 - Dual 4-input expander
//
// Used as an external buffer to widen the AND-array of 74x23 / 74x50 /
// 74x53 / 74x55 AOI gates. The expander generates an X / X_n pair from
// the AND of its 4 inputs and feeds it back into the host gate's
// expander pins.
//
// In synthesizable RTL this internal-node interface does not exist:
// FPGA fabric cannot share wired-AND nodes between chips. The most
// useful interpretation is "the AND of the inputs", which is what we
// output as x. x_n is the complement.
//
// If you actually want to "expand" one of the supported AOI gates, do
// not use this expander — just widen the AOI expression at the next
// level of hierarchy.
// =============================================================================

module ttl_74x60 (
    input  logic [3:0] a1,
    input  logic [3:0] a2,
    output logic       x1,
    output logic       x1_n,
    output logic       x2,
    output logic       x2_n
);
    assign x1   =  (&a1);
    assign x1_n = ~(&a1);
    assign x2   =  (&a2);
    assign x2_n = ~(&a2);
endmodule
