// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x178 - 4-bit parallel-access shift register.
// Modes:
//   s_l & ~clr   : parallel load
//   shift_en     : shift right (din serial in)
//   else         : hold
module ttl_74x178 (
    input  logic       clk,
    input  logic       s_l,        // 1 = parallel load
    input  logic       shift_en,
    input  logic       din,
    input  logic [3:0] p,
    output logic [3:0] q
);
    always_ff @(posedge clk) begin
        if (s_l)            q <= p;
        else if (shift_en)  q <= {din, q[3:1]};
    end
endmodule
