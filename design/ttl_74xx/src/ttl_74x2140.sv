// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2140.md.
// ttl_74x2140 - 8k x 18 cache data RAM
// Sync write, async read.
module ttl_74x2140 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [12:0] addr,
    input  logic [17:0] data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic [17:0] data_out
);
    logic [17:0] mem [0:8191];
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 18'h0;
endmodule
