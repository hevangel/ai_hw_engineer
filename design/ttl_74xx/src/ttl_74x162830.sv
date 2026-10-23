module ttl_74x162830 (
    input logic [17:0] a,
    input logic [1:0] oe_n,
    output logic [17:0] y1,y2,
    output logic [1:0] drive
);
    assign drive=~oe_n;
    assign y1=oe_n[0]?'0:a;
    assign y2=oe_n[1]?'0:a;
endmodule
