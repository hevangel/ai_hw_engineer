// Digital shift/load behavior from TI SN74LS166A.
module ttl_74x166 (
    input logic clk, clk_inh, sh_ld_n, ser,
    input logic [7:0] p,
    input logic clr_n,
    output logic q_h
);
    logic [7:0] sr;
    logic gated_clk;
    assign gated_clk = clk | clk_inh;
    always_ff @(posedge gated_clk or negedge clr_n) begin
        if(!clr_n) sr<=0;
        else if(!sh_ld_n) sr<=p;
        else sr<={sr[6:0],ser};
    end
    assign q_h=sr[7];
endmodule
