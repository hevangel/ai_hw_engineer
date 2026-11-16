// One 64 KB display-buffer plane of the IBM EGA with the Graphics Memory
// Expansion Card fully populated (TR p.4: four planes of 64 KB = 256 KB).
//
// Port A: processor access (synchronous read, write).
// Port B: display refresh read (synchronous).
// Port D: simulation-only debug read (combinational, no side effects).
// The module is a plain dual-port RAM so an FPGA wrapper can replace it with
// block RAM or move it outside the card.
module ega_plane_ram (
    input  logic        clk,
    input  logic [15:0] a_addr,
    input  logic        a_we,
    input  logic [7:0]  a_wdata,
    output logic [7:0]  a_rdata,
    input  logic [15:0] b_addr,
    output logic [7:0]  b_rdata,
    input  logic [15:0] dbg_addr,
    output logic [7:0]  dbg_rdata
);
`ifdef FORMAL
    // Formal: the plane is a black box; its read data are unconstrained.
    (* anyseq *) logic [7:0] f_a, f_b, f_d;
    always_ff @(posedge clk) begin
        a_rdata <= f_a;
        b_rdata <= f_b;
    end
    assign dbg_rdata = f_d;
    logic f_unused;
    assign f_unused = ^{a_addr, a_we, a_wdata, b_addr, dbg_addr};
`else
    logic [7:0] mem [0:65535];

    initial begin
        for (int i = 0; i < 65536; i++) mem[i] = 8'h00;
    end

    always_ff @(posedge clk) begin
        if (a_we) mem[a_addr] <= a_wdata;
        a_rdata <= mem[a_addr];
        b_rdata <= mem[b_addr];
    end

    assign dbg_rdata = mem[dbg_addr];
`endif
endmodule
