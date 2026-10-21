// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x43 - Excess-3-to-decimal decoder, active-low outputs
//
// Excess-3 input: decimal N is encoded as (N + 3) in 4-bit binary.
// Decimal 0  -> 0011
// Decimal 1  -> 0100
// ...
// Decimal 9  -> 1100
// Other input codes (0..2 and 13..15) produce all-high outputs.
// =============================================================================

module ttl_74x43 (
    input  logic [3:0] xs3,
    output logic [9:0] y_n
);

    always_comb begin
        y_n = 10'b1111111111;
        if (xs3 >= 4'd3 && xs3 <= 4'd12) begin
            y_n[xs3 - 4'd3] = 1'b0;
        end
    end

endmodule
