// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x184 - BCD to binary converter.
// Translates 2-digit BCD to 6-bit binary (one digit at a time, used in
// cascade chains). Simplified: takes 8 BCD inputs (2 digits) and outputs
// 6-bit binary equivalent.
module ttl_74x184 (
    input  logic [7:0] bcd,  // upper nibble = high digit, lower = low digit
    output logic [6:0] bin
);
    always_comb begin
        logic [3:0] hi, lo;
        hi = bcd[7:4];
        lo = bcd[3:0];
        if (hi < 10 && lo < 10) bin = 7'(hi * 10 + lo);
        else                    bin = 7'h00;
    end
endmodule
