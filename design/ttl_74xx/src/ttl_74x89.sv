// ASSUMPTION: This RAM exposes a normalized synchronous-write/async-read interface. Native asynchronous write pulses are sampled as a clk transaction; integration must provide this clock explicitly.
// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x89 - 64-bit RAM (16 words x 4 bits), inverted data outputs
//
// FPGA-friendly: synchronous write, async read. The real part has
// open-collector inverted outputs; here the outputs are driven low when
// !cs_n and reflect ~mem[addr] when reading.
// =============================================================================

module ttl_74x89 #(parameter INIT_FILE = "")
(
    input  logic       clk,
    input  logic [3:0] addr,
    input  logic [3:0] data_in,
    input  logic       we_n,
    input  logic       cs_n,
    output logic [3:0] data_out_n
);
    logic [3:0] mem [0:15];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end

    assign data_out_n = (!cs_n) ? ~mem[addr] : 4'h0;
endmodule
