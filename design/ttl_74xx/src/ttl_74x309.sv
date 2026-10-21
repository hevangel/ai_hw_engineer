// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x309.md.
// ttl_74x309 - memory chip
// Sync write, async read.
module ttl_74x309 #(parameter INIT_FILE = "")
(
    input  logic        clk,
    input  logic [9:0] addr,
    input  logic  data_in,
    input  logic        we_n,
    input  logic        cs_n,
    output logic  data_out
);
    logic  mem [0:1023];
    initial begin
        if (INIT_FILE != "") $readmemb(INIT_FILE, mem);
    end
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
    end
    assign data_out = (!cs_n) ? mem[addr] : 1'b0;
endmodule
