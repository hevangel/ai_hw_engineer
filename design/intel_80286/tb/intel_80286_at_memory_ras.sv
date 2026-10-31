// IBM 5170 type-1 sheet 7, U96 F00: +RAS is the NAND of -MEMR and -MEMW.
// This is the delay-line input, not the final bank-specific DRAM RAS# pins.
module intel_80286_at_memory_ras (
    input logic memr_n_i, memw_n_i,
    output logic ras_trigger_o
);
    assign ras_trigger_o = !(memr_n_i && memw_n_i);
endmodule
