// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4040.md.
// ttl_74x4040 - 12-stage binary ripple counter.
module ttl_74x4040 (
    input  logic        clk, rst,
    output logic [11:0] q
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) q <= 12'd0;
        else     q <= q + 12'd1;
    end
endmodule
