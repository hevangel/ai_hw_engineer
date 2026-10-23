`timescale 1ns/1ps
module tb_ttl_74x297;
    logic clk,rst_n,k_clk,id_clk,enctr,down,phase_a1,phase_a2,phase_b;
    logic [3:0] k_sel;
    logic id_out,xorpd_out,ecpd_out,increment,decrement;
    ttl_74x297 dut(.*);
    task automatic sample; clk=0;#1;clk=1;#1;clk=0;#1;endtask
    initial begin
        clk=0;rst_n=0;k_clk=0;id_clk=0;enctr=1;down=0;k_sel=1;
        phase_a1=0;phase_a2=0;phase_b=0;sample;rst_n=1;
        for(int i=1;i<=24;i++) begin
            k_clk=1;sample;
            if(increment !== 1'(i%8==0)) $fatal(1,"K=8 overflow");
            k_clk=0;sample;
        end
        // A pending increment inserts an extra output transition on falling ID.
        id_clk=1;sample;if(id_out!==1) $fatal(1,"base divider");
        id_clk=0;sample;if(id_out!==0) $fatal(1,"insert transition");
        id_clk=1;sample;if(id_out!==1) $fatal(1,"base divider after insertion");
        id_clk=0;sample;if(id_out!==1) $fatal(1,"no unsolicited insertion");
        down=1;
        for(int i=1;i<=8;i++) begin
            k_clk=1;sample;
            if(decrement !== 1'(i==8)) $fatal(1,"down modulo");
            k_clk=0;sample;
        end
        id_clk=1;sample;if(id_out!==1) $fatal(1,"delete transition");
        for(int p=0;p<4;p++) begin
            {phase_a1,phase_b}=2'(p);sample;
            if(xorpd_out !== 1'(p==1 || p==2)) $fatal(1,"XOR phase table");
        end
        phase_a2=1;phase_b=1;sample;
        phase_b=0;sample;if(ecpd_out!==1) $fatal(1,"B falling sets ECPD");
        phase_b=1;sample;if(ecpd_out!==1) $fatal(1,"B rising holds ECPD");
        phase_a2=0;sample;if(ecpd_out!==0) $fatal(1,"A2 falling resets ECPD");
        $display("PASS: tb_ttl_74x297 (K counter, I/D transitions, phase tables)");
        $finish;
    end
endmodule
