`ifdef FORMAL
module ttl_fifo_contract(input logic clk);
    (* anyseq *) logic clr_n,we,re;
    (* anyseq *) logic [3:0] din;
    wire [3:0] dout;
    wire full,empty;
    logic initialized=0;
    logic [4:0] occupancy;
    logic [3:0] queue[0:15];
    wire push=we && !full;
    wire pop=re && !empty;
    ttl_74x222 dut(.*);
    always_ff @(posedge clk) begin
        initialized<=1;
        if(!initialized) assume(!clr_n);
        if(!clr_n) occupancy<=0;
        else begin
            if(initialized) begin
                assert(occupancy<=16);
                assert(empty==(occupancy==0));assert(full==(occupancy==16));
                if(occupancy>0) assert(dout==queue[0]);
                cover(full);cover(occupancy==8 && we && re);
            end
            if(pop) for(integer i=0;i<15;i=i+1) queue[i]<=queue[i+1];
            if(push) queue[occupancy-(pop?1:0)]<=din;
            case({push,pop})
                2'b10:occupancy<=occupancy+1'b1;
                2'b01:occupancy<=occupancy-1'b1;
                default: ;
            endcase
        end
    end
endmodule
`endif
