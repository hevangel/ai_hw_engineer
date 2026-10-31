// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x284 - 4x4 multiplier, high-order 4 bits of product.
module ttl_74x284 (
    input  logic [3:0] a, b,
    output logic [3:0] y_hi
);
    logic [7:0] prod;
    logic [3:0] unused_low_product;
    assign prod = a * b;
    assign {y_hi, unused_low_product} = prod;
endmodule
