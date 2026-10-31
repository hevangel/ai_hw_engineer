`ifdef FORMAL
module ttl_universal_contract(input logic clk);
    (* anyseq *) logic [17:0] a;
    (* anyseq *) logic oe_n;
    logic [15:0] y16,transparent16;
    logic [17:0] y18,transparent18,previous;
    logic drive16,drive18,t_drive16,t_drive18;
    logic initialized=0;
    ttl_74x16334 reg16(.clk(clk),.le(1'b1),.oe_n(oe_n),.a(a[15:0]),.y(y16),.drive(drive16));
    ttl_74x162835 reg18(.clk(clk),.le(1'b0),.oe_n(oe_n),.a(a),.y(y18),.drive(drive18));
    ttl_74x16334 transparent_a(.clk(clk),.le(1'b0),.oe_n(oe_n),.a(a[15:0]),.y(transparent16),.drive(t_drive16));
    ttl_74x162835 transparent_b(.clk(clk),.le(1'b1),.oe_n(oe_n),.a(a),.y(transparent18),.drive(t_drive18));
    always_ff @(posedge clk) begin
        initialized<=1;
        previous<=a;
        if(initialized) begin
            assert(y16==(oe_n?16'd0:previous[15:0]));
            assert(y18==(oe_n?18'd0:previous));
        end
        assert(transparent16==(oe_n?16'd0:a[15:0]));
        assert(transparent18==(oe_n?18'd0:a));
        assert({drive16,drive18,t_drive16,t_drive18}=={4{!oe_n}});
        cover(initialized && !oe_n && y18==18'h2a5a5);
        cover(initialized && oe_n && y16==0 && y18==0);
    end
endmodule
`endif
