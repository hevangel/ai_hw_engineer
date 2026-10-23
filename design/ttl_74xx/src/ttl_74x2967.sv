// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2967.md.
// ttl_74x2967 - DRAM controller/driver for 16k/64k/256k dRAM.
// Same address-mux + RAS/CAS model as ttl_74x409, with 9-bit row/col
// addresses (enough for 256k-class DRAMs).
module ttl_74x2967 (
    input  logic        ras_in, cas_in,
    input  logic [8:0]  row_addr, col_addr,
    output logic        ras_n, cas_n,
    output logic [8:0]  dram_addr
);
    assign ras_n     = ~ras_in;
    assign cas_n     = ~cas_in;
    assign dram_addr = cas_in ? col_addr : row_addr;
endmodule
