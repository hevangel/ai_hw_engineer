// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1762.md.
// ttl_74x1762 - dRAM address controller.
// Same row/column address mux + RAS/CAS strobe pattern as ttl_74x968. The
// 74F1762 is the "address-only" controller in the 74F176x family; refresh
// counters and request arbitration are external.
module ttl_74x1762 (
    input  logic        ras_in, cas_in,
    input  logic [9:0]  row_addr, col_addr,
    output logic        ras_n, cas_n,
    output logic [9:0]  dram_addr
);
    assign ras_n     = ~ras_in;
    assign cas_n     = ~cas_in;
    assign dram_addr = cas_in ? col_addr : row_addr;
endmodule
