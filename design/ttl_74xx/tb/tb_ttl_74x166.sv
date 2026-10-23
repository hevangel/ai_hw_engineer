`timescale 1ns/1ps
module tb_ttl_74x166;
    logic clk,clk_inh,sh_ld_n,ser,q_h;
    logic clr_n;
    logic [7:0] p;
    ttl_74x166 dut(.*);
    initial begin
        clk=0;clk_inh=0;sh_ld_n=1;ser=0;p=0;clr_n=0;#1;clr_n=1;
        for(int word_value=0;word_value<256;word_value++) begin
            sh_ld_n=0;p=8'(word_value);#1;
            clk=1;#1;clk=0;#1;
            sh_ld_n=1;#1;
            for(int step=0;step<8;step++) begin
                int bit_number; bit_number=7-step;
                if(q_h !== p[bit_number]) $fatal(1,"MSB-first shift word=%h bit=%d",p,bit_number);

                clk=1;#1;clk=0;#1;
            end
            if(q_h !== 0) $fatal(1,"serial flush");
        end
        // Hold the OR-gated clock high while toggling its other input.
        clk=1;clk_inh=1;#1;ser=1;
        repeat(16) begin clk=0;#1;clk=1;#1;end
        if(q_h!==0) $fatal(1,"clock inhibit");
        $display("PASS: tb_ttl_74x166 (256 load patterns and complete serial chains)");
        $finish;
    end
endmodule
