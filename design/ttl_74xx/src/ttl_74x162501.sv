// ASSUMPTION: native setup/hold and qualified LE changes; split digital buses.
module ttl_74x162501 (
    input logic [17:0] a_in,b_in,
    input logic clk_ab,clk_ba,le_ab,le_ba,
    input logic oe_ab,oe_ba_n,
    output logic [17:0] a_out,b_out,
    output logic ab_drive,ba_drive
);
    assign ab_drive=oe_ab;
    assign ba_drive=!oe_ba_n;

    for(genvar bit_index=0;bit_index<18;bit_index++) begin : g_ab
        logic set_bit,clear_bit,state;
        assign set_bit=le_ab && a_in[bit_index];
        assign clear_bit=le_ab && !a_in[bit_index];
        always_ff @(posedge clk_ab or posedge set_bit or posedge clear_bit) begin
            if(clear_bit) state<=1'b0;
            else if(set_bit) state<=1'b1;
            else state<=a_in[bit_index];
        end
        assign b_out[bit_index]=ab_drive?state:1'b0;
    end

    for(genvar bit_index=0;bit_index<18;bit_index++) begin : g_ba
        logic set_bit,clear_bit,state;
        assign set_bit=le_ba && b_in[bit_index];
        assign clear_bit=le_ba && !b_in[bit_index];
        always_ff @(posedge clk_ba or posedge set_bit or posedge clear_bit) begin
            if(clear_bit) state<=1'b0;
            else if(set_bit) state<=1'b1;
            else state<=b_in[bit_index];
        end
        assign a_out[bit_index]=ba_drive?state:1'b0;
    end

endmodule
