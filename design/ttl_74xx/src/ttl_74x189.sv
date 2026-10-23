// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x189 - 64-bit RAM (16x4) with inverted outputs (variant of 74x89).
module ttl_74x189 #(parameter INIT_FILE = "")
(
    input  logic       clk,
    input  logic [3:0] addr,
    input  logic [3:0] data_in,
    input  logic       we_n,
    input  logic       cs_n,
    output logic [3:0] data_out_n,
    output logic [3:0] drive_en
);
    logic [3:0] mem [0:15];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out_n = (!cs_n) ? ~mem[addr] : 4'h0;
    assign drive_en = {4{~cs_n & we_n}};
endmodule
