// Blackbox stub for the synthesis boundary: si_memory is the external
// storage interface (ROM image + work RAM + VRAM), following the ibm_pc
// and Altair conventions. Read with read_verilog -lib by run_synth.sh.
(* blackbox *)
module si_memory (
    input logic clk,
    input logic [15:0] cpu_addr,
    output logic [7:0] cpu_rdata,
    input logic [15:0] waddr,
    input logic [7:0] wdata,
    input logic we,
    input logic [12:0] win_addr,
    output logic [7:0] win_rdata,
    input logic [15:0] dbg_addr,
    output logic [7:0] dbg_rdata
);
endmodule
