// Blackbox stub for the synthesis boundary. altair_ram.sv is the simulation
// memory model; the board RTL treats it as an explicit external storage
// interface, exactly as system/ibm_pc keeps RAM outside its synthesizable
// motherboard. run_synth.sh reads this stub with read_verilog -lib.
(* blackbox *)
module altair_ram #(
    parameter int RAM_KIB = 16
) (
    input logic clk,
    input logic [15:0] cpu_addr,
    output logic [7:0] cpu_rdata,
    input logic [15:0] waddr,
    input logic [7:0] wdata,
    input logic we,
    input logic [15:0] panel_addr,
    output logic [7:0] panel_rdata,
    input logic [15:0] host_addr,
    output logic [7:0] host_rdata
);
endmodule
