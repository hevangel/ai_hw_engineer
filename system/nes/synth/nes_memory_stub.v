// Blackbox for the NES storage model (RAM, CIRAM, PRG/CHR, PRG RAM): an
// external interface for the synthesis check.
(* blackbox *)
module nes_memory (
    input cpu_clk, input clk,
    input [15:0] cpu_addr, input cpu_we, input [7:0] cpu_wdata, input [18:0] prg_addr,
    output [7:0] ram_rdata, output [7:0] prg_rdata, output [7:0] wram_rdata,
    input ppu_we, input [7:0] ppu_wdata, input [17:0] chr_addr, input chr_sel, input chr_ram_i,
    input [10:0] ciram_addr, output [7:0] chr_rdata, output [7:0] ciram_rdata,
    input [15:0] host_addr, output [7:0] host_rdata
);
endmodule
