// TI SDLS153A functional divider table.
// Normalized single clock; external gating combines the native CLK1/CLK2 pins.
module ttl_74x294 (
    input logic clk, clr_n,
    input logic [4:0] div_sel,
    output logic q
);
    logic [14:0] count;
    logic [14:0] unused_count;
    assign unused_count = count;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) count <= '0;
        else if(div_sel >= 2 && div_sel <= 15) count <= count + 1'b1;
    end
    always_comb begin
        q = 1'b0;
        if(div_sel >= 2 && div_sel <= 15) q = count[4'(div_sel-1'b1)];
    end
endmodule
