// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x968.md.
// ttl_74x968 - DRAM controller/driver for 16k/64k/256k/1M dRAM.
// Modeled after ttl_74x409 but with a 10-bit address path to support up to
// 1Mx1 DRAMs (10 row + 10 col).
module ttl_74x968 (
    input  logic        ras_in, cas_in,
    input  logic [9:0]  row_addr, col_addr,
    output logic        ras_n, cas_n,
    output logic [9:0]  dram_addr
);
    assign ras_n     = ~ras_in;
    assign cas_n     = ~cas_in;
    assign dram_addr = cas_in ? col_addr : row_addr;
endmodule
