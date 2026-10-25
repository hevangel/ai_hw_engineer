// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4017.md.
// ttl_74x4017 - 5-stage Johnson / decade counter with 10 decoded outputs.
// Counter advances on posedge clk while clk_en_n is low.  Async reset
// (rst) sets the count to 0 and forces q[0] high.  cout pulses high for
// counts 0..4 and low for 5..9 (the carry output of the decade chain).
module ttl_74x4017 (
    input  logic        clk,
    input  logic        clk_en_n,
    input  logic        rst,
    output logic [9:0]  q,
    output logic        cout
);
    logic [3:0] cnt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)            cnt <= 4'd0;
        else if (!clk_en_n) cnt <= (cnt == 4'd9) ? 4'd0 : cnt + 4'd1;
    end
    always_comb begin
        q = 10'b0;
        q[cnt] = 1'b1;
    end
    assign cout = (cnt < 4'd5);
endmodule
