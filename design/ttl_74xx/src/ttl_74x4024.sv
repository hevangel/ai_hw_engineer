// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4024.md.
// ttl_74x4024 - 7-stage ripple carry binary counter.
module ttl_74x4024 (
    input  logic        clk, rst,
    output logic [6:0]  q
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) q <= 7'd0;
        else     q <= q + 7'd1;
    end
endmodule
