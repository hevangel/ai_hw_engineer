module sub(input logic clk, input logic [5:0] s);
endmodule
module top(input logic clk);
    logic [5:0] s;
    sub u(.clk(clk), .s(s));
    always_ff @(posedge clk) cover(u.s == 6'd3);
endmodule
