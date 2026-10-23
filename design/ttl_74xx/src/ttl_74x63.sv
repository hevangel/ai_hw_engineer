// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x63 - Hex current-sensing interface gates (digital pass-through).
// The real chip senses current at its inputs and translates to logic for
// driving downstream chips at lower input thresholds. The current-sensing
// is electrical; this RTL provides only the logical pass-through.
module ttl_74x63 (
    input  logic [5:0] a,
    output logic [5:0] y
);
    assign y = a;
endmodule
