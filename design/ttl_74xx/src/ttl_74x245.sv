// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x245 - Octal bus transceiver, 3-state outputs
//
// On the real chip, A and B are bidirectional 8-bit ports. dir selects
// direction (1 = A->B, 0 = B->A); oe_n=1 disables both directions.
//
// FPGA-internal RTL cannot infer tri-state buses. We split each side into
// _in (read) and _out (drive) plus an output-enable status:
//
//   When oe_n=0 and dir=1:  b_out = a_in,   a_out = 0,    b_oe_n = 0, a_oe_n = 1
//   When oe_n=0 and dir=0:  a_out = b_in,   b_out = 0,    a_oe_n = 0, b_oe_n = 1
//   When oe_n=1:            a_out = 0, b_out = 0,         a_oe_n = b_oe_n = 1
//
// To use this against a real bidirectional pin at the top of a design,
// wrap with the FPGA's tri-state pad primitive.
// =============================================================================

module ttl_74x245 (
    input  logic       oe_n,
    input  logic       dir,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       a_oe_n,
    output logic       b_oe_n
);
    always_comb begin
        if (oe_n) begin
            a_out  = 8'h00;
            b_out  = 8'h00;
            a_oe_n = 1'b1;
            b_oe_n = 1'b1;
        end else if (dir) begin
            // A -> B
            a_out  = 8'h00;
            b_out  = a_in;
            a_oe_n = 1'b1;
            b_oe_n = 1'b0;
        end else begin
            // B -> A
            a_out  = b_in;
            b_out  = 8'h00;
            a_oe_n = 1'b0;
            b_oe_n = 1'b1;
        end
    end
endmodule
