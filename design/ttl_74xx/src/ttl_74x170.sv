// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x170 - 16-bit register file (4x4), separate read/write ports.
// Sync write on posedge clk, async read.
module ttl_74x170 (
    input  logic       clk,
    input  logic [1:0] wr_addr,
    input  logic [3:0] wr_data,
    input  logic       we_n,
    input  logic [1:0] rd_addr,
    output logic [3:0] rd_data
);
    logic [3:0] regs [0:3];
    always_ff @(posedge clk) begin
        if (!we_n) regs[wr_addr] <= wr_data;
    end
    assign rd_data = regs[rd_addr];
endmodule
