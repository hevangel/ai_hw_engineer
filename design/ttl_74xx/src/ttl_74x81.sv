// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x81 - 16-bit RAM (16 words x 1 bit)
//
// The original 74x81 is a bipolar TTL RAM with async write timing. For FPGA
// synthesis we add an explicit clock; writes happen on posedge clk while
// !we_n and !cs_n are asserted. Reads are async (combinational from mem).
//
// When cs_n is deasserted, the data output is 0 (the muxed-zero convention
// per spec/spec.md, since the real chip has an open-collector output).
// =============================================================================

module ttl_74x81 #(parameter INIT_FILE = "")
(
    input  logic       clk,
    input  logic [3:0] addr,
    input  logic       data_in,
    input  logic       we_n,
    input  logic       cs_n,
    output logic       data_out
);
    logic mem [0:15];

    initial begin
        if (INIT_FILE != "") $readmemb(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end

    assign data_out = (!cs_n) ? mem[addr] : 1'b0;
endmodule
