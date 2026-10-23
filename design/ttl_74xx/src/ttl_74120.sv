// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74120 - Dual pulse synchronizer / driver.
// Each channel: synchronizes an async input pulse to the clock.
// 2-stage synchronizer FF chain (metastability hardening).
module ttl_74120 (
    input  logic [1:0] clk,
    input  logic [1:0] async_in,
    output logic [1:0] sync_out
);
    logic stage1_0, stage1_1, stage2_0, stage2_1;
    always_ff @(posedge clk[0]) begin
        stage1_0 <= async_in[0];
        stage2_0 <= stage1_0;
    end
    always_ff @(posedge clk[1]) begin
        stage1_1 <= async_in[1];
        stage2_1 <= stage1_1;
    end
    assign sync_out = {stage2_1, stage2_0};
endmodule
