// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x593.md.
// ttl_74x593 - 8-bit binary counter with input register (3-state outputs).
module ttl_74x593 (
    input  logic       clk_cnt, clk_reg, ce_n, cclr_n, load_n, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       rco_n,
    output logic       hiz
);
    logic [7:0] inreg, cnt;
    always_ff @(posedge clk_reg) inreg <= d;
    always_ff @(posedge clk_cnt or negedge cclr_n) begin
        if (!cclr_n)      cnt <= 0;
        else if (!load_n) cnt <= inreg;
        else if (!ce_n)   cnt <= cnt + 1;
    end
    assign q     = oe_n ? 8'b0 : cnt;
    assign rco_n = !((&cnt) && !ce_n);
    assign hiz   = oe_n;
endmodule
