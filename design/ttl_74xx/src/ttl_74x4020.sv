// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4020.md.
// ttl_74x4020 - 14-stage binary counter.
module ttl_74x4020 (
    input  logic        clk, rst,
    output logic [13:0] q
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) q <= 14'd0;
        else     q <= q + 14'd1;
    end
endmodule
