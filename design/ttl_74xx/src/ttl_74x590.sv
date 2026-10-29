// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x590.md.
// ttl_74x590 - 8-bit binary counter with output register, 3-state outputs.
module ttl_74x590 (
    input  logic       clk_cnt, clk_reg, ce_n, cclr_n, oe_n,
    output logic [7:0] q,
    output logic       rco_n,
    output logic       hiz
);
    logic [7:0] cnt, outreg;
    always_ff @(posedge clk_cnt or negedge cclr_n) begin
        if (!cclr_n)    cnt <= 0;
        else if (!ce_n) cnt <= cnt + 1;
    end
    always_ff @(posedge clk_reg) outreg <= cnt;
    assign q     = oe_n ? 8'b0 : outreg;
    assign rco_n = !((&cnt) && !ce_n);
    assign hiz   = oe_n;
endmodule
