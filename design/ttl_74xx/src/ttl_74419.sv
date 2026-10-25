// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74419.md.
// ttl_74419 - Dual modulo-4 counter with shared preload/clear.
module ttl_74419 (
    input  logic [1:0] clk,
    input  logic       clr_n,
    input  logic       load_n,
    input  logic [3:0] d,
    output logic [1:0] q0,
    output logic [1:0] q1
);
    always_ff @(posedge clk[0] or negedge clr_n or negedge load_n) begin
        if (!clr_n)       q0 <= 2'b00;
        else if (!load_n) q0 <= d[1:0];
        else              q0 <= q0 + 2'd1;
    end
    always_ff @(posedge clk[1] or negedge clr_n or negedge load_n) begin
        if (!clr_n)       q1 <= 2'b00;
        else if (!load_n) q1 <= d[3:2];
        else              q1 <= q1 + 2'd1;
    end
endmodule
