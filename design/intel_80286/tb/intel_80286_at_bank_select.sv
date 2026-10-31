// IBM 5170 type-1 sheet 5: U72 PROM address wiring, U63 F20 and U64
// ALS573 latch. PROM contents are supplied externally; this module does not
// assert that a dump from another motherboard revision is equivalent.
module intel_80286_at_bank_select (
    input logic [6:0] a23_a17_i,
    input logic refresh_i, ram_select_n_i, hlda_i, ale_i, mem_cs16_n_i,
    input logic [7:0] prom_data_i,
    output logic [8:0] prom_address_o,
    output logic [3:0] ram_ras_select_o,
    output logic [1:0] ram_cas_select_n_o,
    output logic lmeg_cs_n_o, fsys16_o, f16_o, cs_rom_n_o
);
    logic [7:0] latched;
    assign prom_address_o={ram_select_n_i,refresh_i,a23_a17_i};
    assign cs_rom_n_o=prom_data_i[7];
    assign f16_o=!(prom_data_i[4] && prom_data_i[5] && prom_data_i[7] && mem_cs16_n_i);
    always_latch begin
        if (hlda_i || ale_i) latched = {f16_o,prom_data_i[6:0]};
    end
    assign {fsys16_o,lmeg_cs_n_o,ram_cas_select_n_o,ram_ras_select_o}=latched;
endmodule
