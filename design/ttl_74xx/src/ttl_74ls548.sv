// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls548.md.
// ttl_74ls548 - 8-bit two-stage pipelined register.
module ttl_74ls548 (
    input  logic       clk, clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] s1;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            s1 <= 0;
            q  <= 0;
        end else begin
            s1 <= d;
            q  <= s1;
        end
    end
endmodule
