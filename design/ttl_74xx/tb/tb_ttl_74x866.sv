`timescale 1ns/1ps
module tb_ttl_74x866;
    logic l_a_n,ple,qle,clr_q_n,ole,p_gt_qin,p_lt_qin;
    logic [7:0] p,q;
    logic p_gt_qout,p_lt_qout,p_eq_qout;
    logic [31:0] rng;
    int pv,qv;
    logic eg,el,ee;
    ttl_74x866 dut(.*);
    task automatic compare;
        #1;
        pv=int'({1'b0,p});qv=int'({1'b0,q});
        if(!l_a_n) begin if(p[7]) pv=pv-256;if(q[7]) qv=qv-256;end
        ee=(pv==qv);eg=(pv>qv)||(ee && p_gt_qin);el=(pv<qv)||(ee && p_lt_qin);
        if(p_gt_qout!==eg || p_lt_qout!==el || p_eq_qout!==ee) $fatal(1,"compare signed/unsigned/cascade");
    endtask
    initial begin
        p=0;q=0;l_a_n=1;ple=0;qle=0;clr_q_n=1;ole=0;p_gt_qin=0;p_lt_qin=0;rng='h1234cafe;
        for(int i=0;i<2000;i++) begin
            ole=0;ple=0;qle=0;#1;
            rng=(rng<<1)^(rng[31]?32'h04c11db7:0);
            p=rng[7:0];q=rng[15:8];l_a_n=rng[16];p_gt_qin=rng[17];p_lt_qin=rng[18];
            #1;ple=1;qle=1;#1;ole=1;compare;
            // Hold operands and result independently with stable setup/hold.
            ple=0;qle=0;ole=0;#1;p=~p;q=~q;#1;
            if(p_gt_qout!==eg || p_lt_qout!==el || p_eq_qout!==ee) $fatal(1,"output hold");
            p=~p;q=~q;#1;ole=1;compare;
            // Asynchronous Q clear dominates transparent loading.
            qle=1;clr_q_n=0;#1;q=0;compare;clr_q_n=1;#1;
        end
        $display("PASS: tb_ttl_74x866");$finish;
    end
endmodule
