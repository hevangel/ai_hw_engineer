// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x537.md.
// ttl_74x537 - BCD to decimal decoder with 3-state outputs.
module ttl_74x537 (
    input  logic [3:0] a,
    input  logic       oe_n,
    output logic [9:0] y_n,
    output logic       hiz
);
    always_comb begin
        y_n = 10'b11_1111_1111;
        if (!oe_n && a <= 9) y_n[a] = 1'b0;
        if (oe_n) y_n = 10'b0;
    end
    assign hiz = oe_n;
endmodule
