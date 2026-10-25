// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x610.md.
// ttl_74x610 - memory mapper, latched, with 4-bit input -> 12-bit physical map.
module ttl_74x610 (
    input  logic        clk, wr_n, oe_n, latch_en,
    input  logic [3:0]  virt,
    input  logic [11:0] d,
    output logic [11:0] phys,
    output logic        hiz
);
    logic [11:0] map [0:15];
    logic [11:0] looked_up, latched;
    always_ff @(posedge clk) if (!wr_n) map[virt] <= d;
    always_comb looked_up = map[virt];
    always_latch if (latch_en) latched = looked_up;
    assign phys = oe_n ? 12'b0 : latched;
    assign hiz  = oe_n;
endmodule
