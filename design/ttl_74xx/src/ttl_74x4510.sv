// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4510.md.
// ttl_74x4510 - BCD decade up/down counter with parallel load.
module ttl_74x4510 (
    input  logic       clk, rst,
    input  logic       load_n, ce_n, up_dn,
    input  logic [3:0] d,
    output logic [3:0] q,
    output logic       co_n
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst)           q <= 4'd0;
        else if (!load_n)  q <= d;
        else if (!ce_n) begin
            if (up_dn) q <= (q == 4'd9) ? 4'd0 : q + 4'd1;
            else       q <= (q == 4'd0) ? 4'd9 : q - 4'd1;
        end
    end
    assign co_n = ~(!ce_n &&
                    ((up_dn && q == 4'd9) || (!up_dn && q == 4'd0)));
endmodule
