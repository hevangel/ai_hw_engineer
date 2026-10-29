// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x45 - BCD-to-decimal decoder/driver, OC 30 V
// Same logic as 74x42. OC + 30V drive not modeled.
// =============================================================================

module ttl_74x45 (
    input  logic [3:0] bcd,
    output logic [9:0] y_n
);

    always_comb begin
        y_n = 10'b1111111111;
        if (bcd < 4'd10) begin
            y_n[bcd] = 1'b0;
        end
    end

endmodule
