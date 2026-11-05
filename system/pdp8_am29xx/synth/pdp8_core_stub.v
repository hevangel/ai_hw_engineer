// Synthesis stub for the 4K core memory.  The storage array is an external
// interface in synthesis, as with the other system reconstructions here.
module pdp8_core (
    input  logic        clk_i,
    input  logic [11:0] raddr_i,
    input  logic        re_i,
    input  logic [11:0] waddr_i,
    input  logic        we_i,
    input  logic [11:0] wdata_i,
    input  logic        init_we_i,
    input  logic [11:0] init_addr_i,
    input  logic [11:0] init_data_i,
    output logic [11:0] rdata_o
);
endmodule
