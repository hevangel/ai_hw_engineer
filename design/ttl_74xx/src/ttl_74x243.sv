// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x243 - Quad bus transceiver, non-inverting outputs.
module ttl_74x243 (
    input  logic       oe_n_to_b,
    input  logic       oe_to_a,
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out,
    output logic       a_oe_n, b_oe_n
);
    always_comb begin
        if (!oe_n_to_b && !oe_to_a) begin
            b_out = a_in; a_out = 4'h0; b_oe_n = 0; a_oe_n = 1;
        end else if (oe_n_to_b && oe_to_a) begin
            a_out = b_in; b_out = 4'h0; a_oe_n = 0; b_oe_n = 1;
        end else begin
            a_out = 4'h0; b_out = 4'h0; a_oe_n = 1; b_oe_n = 1;
        end
    end
endmodule
