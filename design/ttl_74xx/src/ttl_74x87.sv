// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x87 - 4-bit true/complement, zero/one element
//
// Selects between b, ~b, all-zeros, all-ones based on two control inputs.
// {s_complement, s_const} encoding:
//   00: y = b           (true)
//   01: y = ~b          (complement)
//   10: y = 4'b0000     (zero)
//   11: y = 4'b1111     (one)
// =============================================================================

module ttl_74x87 (
    input  logic [3:0] b,
    input  logic       s_complement,
    input  logic       s_const,
    output logic [3:0] y
);
    always_comb begin
        case ({s_complement, s_const})
            2'b00: y = b;
            2'b01: y = ~b;
            2'b10: y = 4'b0000;
            2'b11: y = 4'b1111;
            default: y = 4'b0000;
        endcase
    end
endmodule
