// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7294.md.
// ttl_74x7294 - Programmable divider / timer.
// Same behavioral model as ttl_74x7292.
module ttl_74x7294 (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] n,
    output logic        out
);
    logic [31:0] cnt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)               cnt <= 32'd0;
        else if (cnt == 32'd0) cnt <= (n == 32'd0) ? 32'd0 : (n - 32'd1);
        else                   cnt <= cnt - 32'd1;
    end
    assign out = (cnt == 32'd0);
endmodule
