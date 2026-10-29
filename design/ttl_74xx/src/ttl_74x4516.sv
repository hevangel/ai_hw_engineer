// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4516.md.
// ttl_74x4516 - 4-bit binary up/down counter with sync load.
module ttl_74x4516 (
    input  logic       clk, rst,
    input  logic       load_n, ce_n, up_dn,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       co_n
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst)           q <= 4'd0;
        else if (!load_n)  q <= d;
        else if (!ce_n)    q <= up_dn ? (q + 4'd1) : (q - 4'd1);
    end
    assign co_n = ~(!ce_n &&
                    ((up_dn && q == 4'hF) || (!up_dn && q == 4'h0)));
endmodule
