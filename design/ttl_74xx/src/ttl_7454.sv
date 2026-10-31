// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_7454 - 2-2-2-2 AOI gate, non-expandable.
// y = ~((a1&b1) | (a2&b2) | (a3&b3) | (a4&b4))
module ttl_7454 (
    input  logic a1, b1, a2, b2, a3, b3, a4, b4,
    output logic y
);
    assign y = ~((a1 & b1) | (a2 & b2) | (a3 & b3) | (a4 & b4));
endmodule
