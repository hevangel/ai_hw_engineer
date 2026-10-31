`ifdef FORMAL
module ttl_shift_contract(input logic clk);
    (* anyseq *) logic clr_n,a,b;
    wire [7:0] q;
    logic [7:0] history;
    logic initialized=0;
    ttl_74x164 dut(.*);
    always_ff @(posedge clk) begin
        initialized<=1;
        if(!initialized) assume(!clr_n);
        if(initialized && clr_n) assert(q==history);
        if(!clr_n) history<=0;
        else begin
            history[0]<=a && b;
            for(integer i=1;i<8;i=i+1) history[i]<=history[i-1];
        end
        cover(initialized && q==8'ha5);
    end
endmodule
`endif
