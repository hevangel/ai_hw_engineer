// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x611.md.
// ttl_74x611 - memory mapper, latched (open-collector variant of 74x610).
module ttl_74x611 (
    input  logic        clk, wr_n, latch_en,
    input  logic [3:0]  virt,
    input  logic [11:0] d,
    output logic [11:0] phys
);
    logic [11:0] map [0:15];
    logic [11:0] looked_up, latched;
    always_ff @(posedge clk) if (!wr_n) map[virt] <= d;
    always_comb looked_up = map[virt];
    always_latch if (latch_en) latched = looked_up;
    assign phys = latched;
endmodule
