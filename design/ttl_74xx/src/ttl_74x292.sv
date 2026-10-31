// TI SDLS153A functional divider table.
// Normalized single clock; external gating combines the native CLK1/CLK2 pins.
module ttl_74x292 (
    input logic clk, clr_n,
    input logic [4:0] div_sel,
    output logic q
);
    logic [30:0] count;
    logic [30:0] unused_count;
    assign unused_count = count;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) count <= '0;
        else if(div_sel >= 2) count <= count + 1'b1;
    end
    always_comb begin
        q = 1'b0;
        if(div_sel >= 2) q = count[div_sel-1'b1];
    end
endmodule
