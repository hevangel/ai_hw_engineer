// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74l51 - 3-3 AOI gate + 2-2 AOI gate (low-power)
//
// Gate 0 is 3-3: y[0] = ~((a3 & b3 & c3) | (d3 & e3 & f3))
// Gate 1 is 2-2: y[1] = ~((a2 & b2) | (c2 & d2))
//
// Datasheet: SN54L51 / SN74L51.
// =============================================================================

module ttl_74l51 (
    // 3-3 AOI gate
    input  logic a3, b3, c3, d3, e3, f3,
    // 2-2 AOI gate
    input  logic a2, b2, c2, d2,
    output logic [1:0] y
);
    assign y[0] = ~((a3 & b3 & c3) | (d3 & e3 & f3));
    assign y[1] = ~((a2 & b2) | (c2 & d2));
endmodule
