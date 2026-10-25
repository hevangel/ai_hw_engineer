module ttl_74x16344 (
    input logic [7:0] a,
    input logic [3:0] oe_n,
    output logic [31:0] b,drive
);
    for(genvar i=0;i<32;i++) begin : g_output
        assign drive[i]=!oe_n[i/8];
        assign b[i]=oe_n[i/8]?1'b0:a[i/4];
    end
endmodule
