// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x319.md.
// ttl_74x319 - memory chip
// Sync write, async read.
module ttl_74x319 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [3:0] addr,
    input  logic [3:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [3:0] data_out
);
    logic [3:0] mem [0:15];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 4'h0;
endmodule
