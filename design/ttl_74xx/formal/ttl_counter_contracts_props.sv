`ifdef FORMAL
module ttl_counter_contracts(input logic clk);
    (* anyseq *) logic clr_n,load_n,enp,ent;
    (* anyseq *) logic [3:0] d;
    logic initialized=0;
    wire [3:0] q160,q161,q162,q163;
    wire c160,c161,c162,c163;
    logic [3:0] r160,r161,r162,r163;
    function automatic [3:0] next_decimal(input logic [3:0] value);
        case(value)
            0:next_decimal=1;1:next_decimal=2;2:next_decimal=3;3:next_decimal=4;
            4:next_decimal=5;5:next_decimal=6;6:next_decimal=7;7:next_decimal=8;
            8:next_decimal=9;9:next_decimal=0;
            default:next_decimal=value+1'b1;
        endcase
    endfunction
    ttl_74x160 a(.clk(clk),.clr_n(clr_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q160),.rco(c160));
    ttl_74x161 b(.clk(clk),.clr_n(clr_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q161),.rco(c161));
    ttl_74x162 c(.clk(clk),.clr_n(clr_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q162),.rco(c162));
    ttl_74x163 d_inst(.clk(clk),.clr_n(clr_n),.load_n(load_n),.enp(enp),.ent(ent),.d(d),.q(q163),.rco(c163));
    always_ff @(posedge clk) begin
        initialized<=1;
        if(!initialized) assume(!clr_n);
        // BCD load inputs are restricted to documented decimal operation.
        if(!load_n) assume(d<=9);
        if(initialized) begin
            if(clr_n) begin assert(q160==r160);assert(q161==r161);end
            assert(q162==r162);assert(q163==r163);
            assert(c160==(ent && q160==9));assert(c161==(ent && q161==15));
            assert(c162==(ent && q162==9));assert(c163==(ent && q163==15));
            cover(q160==9 && enp && ent);
            cover(q161==15 && enp && ent);
            cover(q160!=0 && !enp && load_n);
            cover(!load_n && d==7);
        end
        if(!clr_n) begin r160<=0;r161<=0;r162<=0;r163<=0;end
        else if(!load_n) begin r160<=d;r161<=d;r162<=d;r163<=d;end
        else if(enp && ent) begin
            r160<=next_decimal(r160);r161<=r161+1'b1;
            r162<=next_decimal(r162);r163<=r163+1'b1;
        end
    end
endmodule
`endif
