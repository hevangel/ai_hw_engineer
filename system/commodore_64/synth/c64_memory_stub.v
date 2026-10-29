// Blackbox stub for the synthesis boundary: c64_memory is the external
// storage interface (DRAM, color SRAM and the three mask ROMs), following
// the space_invaders and ibm_pc conventions. Read with read_verilog -lib by
// run_synth.sh.
(* blackbox *)
module c64_memory (
    input logic cpu_clk,
    input logic [15:0] cpu_addr,
    output logic [7:0] cpu_ram_q,
    output logic [7:0] basic_q,
    output logic [7:0] kernal_q,
    output logic [7:0] charom_q,
    output logic [3:0] cpu_color_q,
    input logic ram_we,
    input logic [7:0] ram_wdata,
    input logic color_we,
    input logic [15:0] vic1_addr,
    output logic [7:0] vic1_ram_q,
    output logic [7:0] vic1_rom_q,
    input logic [15:0] vic2_addr,
    output logic [7:0] vic2_ram_q,
    output logic [7:0] vic2_rom_q,
    input logic [9:0] vic_color_addr,
    output logic [3:0] vic_color_q,
    input logic [15:0] host_addr,
    output logic [7:0] host_ram_q,
    output logic [3:0] host_color_q
);
endmodule
