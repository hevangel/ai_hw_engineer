// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7074.md.
// ttl_74x7074 - Mixed package: two inverters, one 2-input NAND,
// one 2-input NOR, two D-type flip-flops (positive-edge triggered).
module ttl_74x7074 (
    input  logic [1:0] inv_a,
    output logic [1:0] inv_y,
    input  logic       nand_a, nand_b,
    output logic       nand_y,
    input  logic       nor_a, nor_b,
    output logic       nor_y,
    input  logic       clk1, clr1_n, pre1_n, d1,
    output logic       q1, q1_n,
    input  logic       clk2, clr2_n, pre2_n, d2,
    output logic       q2, q2_n
);
    assign inv_y  = ~inv_a;
    assign nand_y = ~(nand_a & nand_b);
    assign nor_y  = ~(nor_a  | nor_b);

    logic r1, r2;
    always_ff @(posedge clk1 or negedge clr1_n or negedge pre1_n) begin
        if (!clr1_n)      r1 <= 0;
        else if (!pre1_n) r1 <= 1;
        else              r1 <= d1;
    end
    always_ff @(posedge clk2 or negedge clr2_n or negedge pre2_n) begin
        if (!clr2_n)      r2 <= 0;
        else if (!pre2_n) r2 <= 1;
        else              r2 <= d2;
    end
    assign q1 = r1; assign q1_n = ~r1;
    assign q2 = r2; assign q2_n = ~r2;
endmodule
