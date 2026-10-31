// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x202 - 256-bit RAM (256x1) with power-down
// Sync write, async read.
module ttl_74x202 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [7:0] addr,
    input  logic  data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic  data_out,
    output logic  drive_en
);
    logic  mem [0:255];
    initial begin
        if (INIT_FILE != "") $readmemb(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 1'b0;
    assign drive_en = ~cs_n & we_n;
endmodule
