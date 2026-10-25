// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x409.md.
// ttl_74x409 - DRAM controller/driver (same as 74s408).
module ttl_74x409 (
    input  logic        ras_in, cas_in,
    input  logic [8:0]  row_addr, col_addr,
    output logic        ras_n, cas_n,
    output logic [8:0]  dram_addr
);
    assign ras_n = ~ras_in;
    assign cas_n = ~cas_in;
    assign dram_addr = cas_in ? col_addr : row_addr;
endmodule
