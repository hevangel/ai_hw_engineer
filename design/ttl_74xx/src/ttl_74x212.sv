// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x212 - 144-bit RAM (16x9)
// Sync write, async read.
module ttl_74x212 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [3:0] addr,
    input  logic [8:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [8:0] data_out,
    output logic [8:0] drive_en
);
    logic [8:0] mem [0:15];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 9'h0;
    assign drive_en = {9{~cs_n & we_n}};
endmodule
