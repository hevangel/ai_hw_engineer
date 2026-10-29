// Digital functional model of TI SN74LS297, SDLS155, pp.2-4.
// clk samples the native K/I-D clocks and phase-detector inputs; all external
// transitions must be resolved as separate clk samples. rst_n represents POR.
module ttl_74x297 (
    input logic clk, rst_n,
    input logic k_clk, id_clk, enctr, down,
    input logic [3:0] k_sel,
    input logic phase_a1, phase_a2, phase_b,
    output logic id_out, xorpd_out, ecpd_out,
    output logic increment, decrement
);
    logic k_prev, id_prev, a_prev, b_prev;
    logic [16:0] up_count, down_count;
    logic [16:0] k_mask;
    logic inc_pending, dec_pending;
    assign k_mask = 17'h1ffff >> (5'd15 - {1'b0,k_sel});
    assign xorpd_out = phase_a1 ^ phase_b;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            k_prev<=0; id_prev<=0; a_prev<=0; b_prev<=0;
            up_count<=0; down_count<=0; id_out<=0; ecpd_out<=0;
            increment<=0; decrement<=0; inc_pending<=0; dec_pending<=0;
        end else begin
            k_prev<=k_clk; id_prev<=id_clk; a_prev<=phase_a2; b_prev<=phase_b;
            increment<=0; decrement<=0;
            if(b_prev && !phase_b) ecpd_out<=1;
            else if(a_prev && !phase_a2) ecpd_out<=0;
            if(k_clk && !k_prev && enctr && k_sel!=0) begin
                if(down) begin
                    if(down_count==k_mask) begin
                        down_count<=0; decrement<=1; dec_pending<=1;
                    end else down_count<=(down_count+1'b1)&k_mask;
                end else begin
                    if(up_count==k_mask) begin
                        up_count<=0; increment<=1; inc_pending<=1;
                    end else up_count<=(up_count+1'b1)&k_mask;
                end
            end
            if(id_clk && !id_prev) begin
                if(dec_pending) dec_pending<=0;
                else id_out<=~id_out;
            end
            if(!id_clk && id_prev && inc_pending) begin
                id_out<=~id_out; inc_pending<=0;
            end
        end
    end
endmodule
