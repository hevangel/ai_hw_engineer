// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x438.md.
// ttl_74x438 - System controller for Intel 8080A (Intel 8238).
// Same as 74x428.
module ttl_74x438 (
    input  logic [7:0] status,
    input  logic       dbin, wr_n, hlda,
    output logic       mem_r_n, mem_w_n, io_r_n, io_w_n, inta_n
);
    logic unused_status;
    assign unused_status = ^{status[5:4], status[2]};
    assign mem_r_n = ~(!hlda & status[7] & dbin);
    assign mem_w_n = ~(!hlda & (~status[1]) & ~status[3] & ~wr_n);
    assign io_r_n  = ~(!hlda & status[6] & dbin);
    assign io_w_n  = ~(!hlda & status[3] & ~wr_n);
    assign inta_n  = ~(!hlda & status[0] & dbin);
endmodule
