// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x420.md.
// ttl_74x420 - 32-bit check bit / syndrome bit generator.
module ttl_74x420 (
    input  logic [31:0] data,
    output logic [6:0]  check
);
    assign check[0] = ^(data & 32'h55555555);
    assign check[1] = ^(data & 32'h33333333);
    assign check[2] = ^(data & 32'h0F0F0F0F);
    assign check[3] = ^(data & 32'h00FF00FF);
    assign check[4] = ^(data & 32'h0000FFFF);
    assign check[5] = ^data;
    assign check[6] = ^data;
endmodule
