// ASSUMPTION: ideal digital levels and documented LE setup/hold; see part spec.
module ttl_74x16334 (
    input logic clk,le,oe_n,
    input logic [15:0] a,
    output logic [15:0] y,
    output logic drive
);
    logic [15:0] stored;
    for(genvar bit_index=0;bit_index<16;bit_index++) begin : g_bit
        logic set_bit,clear_bit,state;
        assign set_bit=(!le) && a[bit_index];
        assign clear_bit=(!le) && !a[bit_index];
        always_ff @(posedge clk or posedge set_bit or posedge clear_bit) begin
            if(clear_bit) state<=1'b0;
            else if(set_bit) state<=1'b1;
            else state<=a[bit_index];
        end
        assign stored[bit_index]=state;
    end
    assign drive=!oe_n;
    assign y=oe_n?'0:stored;
endmodule
