// Native active-low SR functions. Sections 0 and 2 each have two set inputs.
module ttl_74x279 (
    input logic [3:0] s_n, r_n,
    input logic [1:0] s2_n,
    output logic [3:0] q
);
    for(genvar i=0;i<4;i++) begin : g_latch
        logic set_n, state;
        if(i==0) begin : g_first
            assign set_n=s_n[i]&s2_n[0];
        end else if(i==2) begin : g_third
            assign set_n=s_n[i]&s2_n[1];
        end else begin : g_single
            assign set_n=s_n[i];
        end
        always_latch begin
            if(!set_n) state=1;
            else if(!r_n[i]) state=0;
        end
        assign q[i]=state;
    end
endmodule
