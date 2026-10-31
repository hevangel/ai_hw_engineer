// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x592.md.
// ttl_74x592 - 8-bit binary counter with input register.
module ttl_74x592 (
    input  logic       clk_cnt, clk_reg, ce_n, cclr_n, load_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       rco_n
);
    logic [7:0] inreg, cnt;
    always_ff @(posedge clk_reg) inreg <= d;
    always_ff @(posedge clk_cnt or negedge cclr_n) begin
        if (!cclr_n)      cnt <= 0;
        else if (!load_n) cnt <= inreg;
        else if (!ce_n)   cnt <= cnt + 1;
    end
    assign q     = cnt;
    assign rco_n = !((&cnt) && !ce_n);
endmodule
