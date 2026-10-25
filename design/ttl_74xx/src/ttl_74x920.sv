// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x920.md.
// ttl_74x920 - 1024-bit RAM (256x4), separate data inputs and outputs
// Sync write, async read.
module ttl_74x920 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [7:0] addr,
    input  logic [3:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [3:0] data_out
);
    logic [3:0] mem [0:255];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 4'h0;
endmodule
