// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x385.md.
// ttl_74x385 - Quad serial adder/subtractor.
// Four 1-bit serial adders with shared carry. sub_n=1 selects add, sub_n=0 selects subtract.
module ttl_74x385 (
    input  logic [3:0] a, b,
    input  logic       cin,
    input  logic       sub_n,
    output logic [3:0] s,
    output logic       cout
);
    logic [3:0] b_eff;
    logic [4:0] r;
    assign b_eff = sub_n ? b : ~b;
    assign r = {1'b0, a} + {1'b0, b_eff} + {4'b0, (sub_n ? cin : ~cin)};
    assign s    = r[3:0];
    assign cout = r[4];
endmodule
