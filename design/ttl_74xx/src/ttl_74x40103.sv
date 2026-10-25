// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x40103.md.
// ttl_74x40103 - Presettable 8-bit synchronous down counter.
// Same model as ttl_74x4103.
module ttl_74x40103 (
    input  logic       clk, rst,
    input  logic       load_n, ce_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       tc_n
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst)           q <= 8'd0;
        else if (!load_n)  q <= d;
        else if (!ce_n)    q <= q - 8'd1;
    end
    assign tc_n = ~(q == 8'd0);
endmodule
