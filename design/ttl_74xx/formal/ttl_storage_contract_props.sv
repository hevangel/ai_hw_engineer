`ifdef FORMAL
module ttl_storage_contract(input logic clk);
    (* anyseq *) logic [7:0] d;
    (* anyseq *) logic oe_n;
    logic [7:0] q,previous;
    logic hiz;
    logic valid=0;
    ttl_74x574 dut(.*);
    always_ff @(posedge clk) begin
        valid<=1;
        previous<=d;
        if(valid) begin
            assert(q==(oe_n?8'b0:previous));
            assert(hiz==oe_n);
        end
        cover(valid && !oe_n && q==8'ha5);
        cover(valid && oe_n && q==0);
    end
endmodule
`endif
