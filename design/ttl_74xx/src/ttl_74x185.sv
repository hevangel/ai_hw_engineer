// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x185 - 6-bit binary to BCD converter.
// Takes a 6-bit binary value (0..63) and produces 8-bit BCD output {hi, lo}.
module ttl_74x185 (
    input  logic [5:0] bin,
    output logic [7:0] bcd
);
    logic [3:0] hi, lo;
    always_comb begin
        hi = 4'(bin / 10);
        lo = 4'(bin % 10);
        bcd = {hi, lo};
    end
endmodule
