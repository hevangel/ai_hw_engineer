// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x141 - BCD-to-decimal decoder/driver for Nixie (OC HV).
// Same logic as 74x42; OC + HV drive not modeled.
module ttl_74x141 (
    input  logic [3:0] bcd,
    output logic [9:0] y_n
);
    always_comb begin
        y_n = 10'b1111111111;
        if (bcd < 4'd10) y_n[bcd] = 1'b0;
    end
endmodule
