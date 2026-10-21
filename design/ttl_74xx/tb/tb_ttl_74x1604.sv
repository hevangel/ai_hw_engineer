`timescale 1ns/1ps
module tb_ttl_74x1604;
    logic [7:0] a,b,q,held_a,held_b;
    logic sel_ab,le_n;
    ttl_74x1604 dut(.*);
    task automatic check;
        #1;if(q!==(sel_ab?held_a:held_b)) $fatal(1,"latch/mux mismatch");
    endtask
    initial begin
        a=0;b=0;sel_ab=0;le_n=1;
        for(int i=0;i<256;i++) begin
            le_n=0;#1;a=8'(i);b=8'(i^'ha5);held_a=a;held_b=b;check;
            sel_ab=1;check;sel_ab=0;check;
            le_n=1;#1;a=~held_a;b=~held_b;check;
            sel_ab=1;check;sel_ab=0;check;
        end
        $display("PASS: tb_ttl_74x1604");$finish;
    end
endmodule
