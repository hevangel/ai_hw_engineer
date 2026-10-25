// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x612.md.
// ttl_74x612 - memory mapper (unlatched, 3-state outputs).
module ttl_74x612 (
    input  logic        clk, wr_n, oe_n,
    input  logic [3:0]  virt,
    input  logic [11:0] d,
    output logic [11:0] phys,
    output logic        hiz
);
    logic [11:0] map [0:15];
    always_ff @(posedge clk) if (!wr_n) map[virt] <= d;
    assign phys = oe_n ? 12'b0 : map[virt];
    assign hiz  = oe_n;
endmodule
