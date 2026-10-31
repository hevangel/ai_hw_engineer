// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x410.md.
// ttl_74x410 - 64-bit RAM (16x4) with output register.
module ttl_74x410 #(parameter INIT_FILE = "")
(
    input  logic       clk,
    input  logic [3:0] addr,
    input  logic [3:0] data_in,
    input  logic       we_n,
    input  logic       cs_n,
    output logic [3:0] data_out
);
    logic [3:0] mem [0:15];
    logic [3:0] dout_reg;
    initial if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    always_ff @(posedge clk) begin
        if (!cs_n && !we_n) mem[addr] <= data_in;
        dout_reg <= mem[addr];
    end
    assign data_out = (!cs_n) ? dout_reg : 4'h0;
endmodule
