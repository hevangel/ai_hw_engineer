// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x362.md.
// ttl_74x362 - 4-phase clock generator for TMS9900.
// Generates 4 non-overlapping phase pulses.
module ttl_74x362 (
    input  logic       clk,
    input  logic       clr_n,
    output logic [3:0] phi
);
    logic [1:0] state;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) state <= 2'd0;
        else        state <= state + 2'd1;
    end
    always_comb begin
        phi = 4'h0;
        phi[state] = 1'b1;
    end
endmodule
