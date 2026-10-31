// ASSUMPTION: normalized latch_en polarity/control; see local part specification.
// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x311.md.
// ttl_74x311 - memory chip
// Sync write, async read.
module ttl_74x311 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input logic latch_en,
    input  logic [3:0] addr,
    input  logic [8:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [8:0] data_out
);
    logic [8:0] mem [0:15];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    logic [8:0] held;
    always_latch if (latch_en) held = mem[addr];
    assign data_out = (!cs_n) ? held : 9'h0;
endmodule
