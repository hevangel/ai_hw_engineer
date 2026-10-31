// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x218 - 256-bit RAM (32x8)
// Sync write, async read.
module ttl_74x218 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [4:0] addr,
    input  logic [7:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [7:0] data_out,
    output logic [7:0] drive_en
);
    logic [7:0] mem [0:31];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 8'h0;
    assign drive_en = {8{~cs_n & we_n}};
endmodule
