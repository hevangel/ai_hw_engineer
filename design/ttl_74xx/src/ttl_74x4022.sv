// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4022.md.
// ttl_74x4022 - 4-stage Johnson / divide-by-8 counter with 8 decoded outputs.
module ttl_74x4022 (
    input  logic        clk,
    input  logic        clk_en_n,
    input  logic        rst,
    output logic [7:0]  q,
    output logic        cout
);
    logic [2:0] cnt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)            cnt <= 3'd0;
        else if (!clk_en_n) cnt <= cnt + 3'd1;
    end
    always_comb begin
        q = 8'b0;
        q[cnt] = 1'b1;
    end
    assign cout = (cnt < 3'd4);
endmodule
