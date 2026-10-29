// Blackbox for the SNES storage model (WRAM, cartridge ROM/SRAM, VRAM,
// audio RAM): an external interface for the synthesis check.
(* blackbox *)
module snes_memory (
    input clk,
    input [16:0] wram_addr, input wram_we, input [7:0] wram_wdata, output [7:0] wram_rdata,
    input [21:0] rom_addr, output [7:0] rom_rdata,
    input [16:0] sram_addr, input sram_we, input [7:0] sram_wdata, output [7:0] sram_rdata,
    input [14:0] vram_raddr, output [15:0] vram_rdata,
    input [14:0] vram_caddr, input vram_cwe_lo, input vram_cwe_hi, input [7:0] vram_cwdata,
    output [15:0] vram_cdata,
    input [15:0] aram_addr, input aram_we, input [7:0] aram_wdata, output [7:0] aram_rdata,
    input [23:0] host_addr, output [7:0] host_rdata
);
endmodule
