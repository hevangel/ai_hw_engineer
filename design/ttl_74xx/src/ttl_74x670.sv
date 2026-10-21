// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x670.md.
// ttl_74x670 - 4-word x 4-bit register file with separate read/write ports.
//
// Per SN74LS670: data on D1-D4 is loaded into the register selected by the
// write address (WB,WA) while /GW is low (level-sensitive, latch-style; the
// addressed cell is transparent — it follows D until /GW goes high).
// /GR enables the 3-state outputs reading from the register addressed by
// (RB,RA). Read and write ports are independent.
module ttl_74x670 (
    input  logic       gw_n,
    input  logic       gr_n,
    input  logic [1:0] wa,
    input  logic [1:0] ra,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       q_oe_n
);
    logic [3:0] mem [4];

    always_latch begin
        if (!gw_n) mem[wa] = d;
    end

    assign q_oe_n = gr_n;
    assign q      = gr_n ? 4'h0 : mem[ra];
endmodule
