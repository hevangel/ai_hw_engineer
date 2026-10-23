// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x591.md.
// ttl_74x591 - 8-bit binary counter with output register, open-collector outputs (digital model: active driver).
module ttl_74x591 (
    input  logic       clk_cnt, clk_reg, ce_n, cclr_n,
    output logic [7:0] q,
    output logic       rco_n
);
    logic [7:0] cnt, outreg;
    always_ff @(posedge clk_cnt or negedge cclr_n) begin
        if (!cclr_n)    cnt <= 0;
        else if (!ce_n) cnt <= cnt + 1;
    end
    always_ff @(posedge clk_reg) outreg <= cnt;
    assign q     = outreg;
    assign rco_n = !((&cnt) && !ce_n);
endmodule
