// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x172 - 16-bit multi-port register file (8x2).
// Two write ports (only one enabled at a time) and two read ports.
module ttl_74x172 (
    input  logic       clk,
    input  logic [2:0] wr_addr,
    input  logic [1:0] wr_data,
    input  logic       we_n,
    input  logic [2:0] rd_a_addr,
    input  logic [2:0] rd_b_addr,
    output logic [1:0] rd_a_data,
    output logic [1:0] rd_b_data
);
    logic [1:0] regs [0:7];
    always_ff @(posedge clk) begin
        if (!we_n) regs[wr_addr] <= wr_data;
    end
    assign rd_a_data = regs[rd_a_addr];
    assign rd_b_data = regs[rd_b_addr];
endmodule
