// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x96 - 5-bit parallel-in / parallel-out shift register, async preset.
// Each posedge: shift right with din serial input.
// Async preset: when pre is high, q is OR-loaded with pre_d (set bits go to 1).
module ttl_74x96 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       pre,
    input  logic [4:0] pre_d,
    input  logic       din,
    output logic [4:0] q
);
    for (genvar bit_index = 0; bit_index < 5; bit_index++) begin : g_bit
        logic state;
        logic set_bit;
        logic serial_data;
        assign set_bit = pre & pre_d[bit_index];
        if (bit_index == 4) begin : g_serial
            assign serial_data = din;
        end else begin : g_previous
            assign serial_data = q[bit_index+1];
        end
        assign q[bit_index] = state;
        always_ff @(posedge clk or negedge clr_n or posedge set_bit) begin
            if (!clr_n) state <= 1'b0;
            else if (set_bit) state <= 1'b1;
            else if (!pre) state <= serial_data;
        end
    end
endmodule
