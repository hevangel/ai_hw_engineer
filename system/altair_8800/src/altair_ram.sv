// Altair 8800 static RAM simulation model. Like the IBM PC system's
// motherboard RTL, storage lives outside the synthesizable board boundary:
// scripts/run_synth.sh treats this module as a blackbox. Three async read
// ports (CPU bus, panel display, host window) and one shared write port
// (the panel and the CPU never write in the same cycle; the panel only
// acts while the CPU is held with HLDA).
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
    localparam int AW = $clog2(RAM_KIB * 1024);
    logic [7:0] mem [0:RAM_KIB * 1024 - 1];

    function automatic logic in_ram(input logic [15:0] addr);
        in_ram = (addr >> AW) == 16'd0;
    endfunction

    assign cpu_rdata = in_ram(cpu_addr) ? mem[cpu_addr[AW-1:0]] : 8'hff;
    assign panel_rdata = in_ram(panel_addr) ? mem[panel_addr[AW-1:0]] : 8'hff;
    assign host_rdata = in_ram(host_addr) ? mem[host_addr[AW-1:0]] : 8'hff;

    always_ff @(posedge clk) begin
        if (we && in_ram(waddr)) mem[waddr[AW-1:0]] <= wdata;
    end

    initial begin
        for (integer i = 0; i < RAM_KIB * 1024; i = i + 1) mem[i] = 8'd0;
    end
endmodule
