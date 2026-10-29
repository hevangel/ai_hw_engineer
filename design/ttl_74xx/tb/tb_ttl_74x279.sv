`timescale 1ns/1ps
module tb_ttl_74x279;
    logic [3:0] s_n,r_n,q;
    logic [1:0] s2_n;
    ttl_74x279 dut(.*);
    initial begin
        s_n=15;s2_n=3;r_n=0;#1;if(q!==0)$fatal(1,"reset");
        r_n=15;s_n=0;#1;if(q!==15)$fatal(1,"set");
        s_n=15;#1;if(q!==15)$fatal(1,"hold");
        r_n=0;#1;s2_n=0;#1;if(q!==4'b0101)$fatal(1,"secondary set");
        s_n=0;#1;if(q!==15)$fatal(1,"dual asserted forces high");
        s_n=15;s2_n=3;#1;if(q!==0)$fatal(1,"reset after set release");
        $display("PASS: tb_ttl_74x279 (reset/set/hold and secondary set pins)");$finish;
    end
endmodule
