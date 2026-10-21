// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x183 - Dual carry-save full adder.
// Two independent 1-bit full adders. Each: {c_out, s} = a + b + cin.
module ttl_74x183 (
    input  logic [1:0] a, b, cin,
    output logic [1:0] s,
    output logic [1:0] c_out
);
    assign {c_out[0], s[0]} = {1'b0, a[0]} + {1'b0, b[0]} + {1'b0, cin[0]};
    assign {c_out[1], s[1]} = {1'b0, a[1]} + {1'b0, b[1]} + {1'b0, cin[1]};
endmodule
