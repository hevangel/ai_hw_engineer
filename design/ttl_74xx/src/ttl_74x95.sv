// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x95 - 4-bit shift register, parallel-in / parallel-out, serial input.
//
// Two clocks on the original chip (CLK1 for shift, CLK2 for load). For FPGA
// synthesis we combine into a single posedge clk with a mode select.
//
// mode = 1: parallel load (q <= p)
// mode = 0: shift right (q <= {din, q[3:1]})
//
// We expose both serial input (din) and parallel input (p).
// =============================================================================

module ttl_74x95 (
    input  logic       clk,
    input  logic       mode,
    input  logic       din,
    input  logic [3:0] p,
    output logic [3:0] q
);
    always_ff @(posedge clk) begin
        if (mode) q <= p;
        else      q <= {din, q[3:1]};
    end
endmodule
