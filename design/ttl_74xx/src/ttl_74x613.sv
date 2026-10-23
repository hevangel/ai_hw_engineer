// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x613.md.
// ttl_74x613 - memory mapper (unlatched, OC outputs).
module ttl_74x613 (
    input  logic        clk, wr_n,
    input  logic [3:0]  virt,
    input  logic [11:0] d,
    output logic [11:0] phys
);
    logic [11:0] map [0:15];
    always_ff @(posedge clk) if (!wr_n) map[virt] <= d;
    assign phys = map[virt];
endmodule
