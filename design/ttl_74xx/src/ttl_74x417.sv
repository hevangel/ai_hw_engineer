// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x417.md.
// ttl_74x417 - Modulo-2 and modulo-5 counters with shared preload/clear.
module ttl_74x417 (
    input  logic       clk_a,
    input  logic       clk_b,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic       q_a,
    output logic [2:0] q_b
);
    always_ff @(posedge clk_a or negedge clr_n or negedge load_n) begin
        if (!clr_n)       q_a <= 1'b0;
        else if (!load_n) q_a <= d[0];
        else              q_a <= ~q_a;
    end
    always_ff @(posedge clk_b or negedge clr_n or negedge load_n) begin
        if (!clr_n)             q_b <= 3'b000;
        else if (!load_n)       q_b <= d[3:1];
        else if (q_b == 3'b100) q_b <= 3'b000;
        else                    q_b <= q_b + 3'b001;
    end
endmodule
