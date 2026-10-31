// Digital shift/load behavior from TI SN74LS165A.
module ttl_74x165 (
    input logic clk, clk_inh, sh_ld_n, ser,
    input logic [7:0] p,
    output logic q_h, q_h_n
);
    logic [7:0] sr;
    logic gated_clk;
    assign gated_clk = clk | clk_inh;
    for(genvar i=0;i<8;i++) begin : g_bit
        logic state, set_bit, clear_bit, shift_data;
        assign set_bit = !sh_ld_n & p[i];
        assign clear_bit = !sh_ld_n & !p[i];
        if(i==0) begin : g_in
            assign shift_data = ser;
        end else begin : g_shift
            assign shift_data = sr[i-1];
        end
        assign sr[i] = state;
        always_ff @(posedge gated_clk or posedge set_bit or posedge clear_bit) begin
            if(clear_bit) state <= 0;
            else if(set_bit) state <= 1;
            else state <= shift_data;
        end
    end
    assign q_h=sr[7];
    assign q_h_n=~sr[7];
endmodule
