`timescale 1ns/1ps
module tb_ttl_74x294;
    logic clk,clr_n,q;
    logic [4:0] div_sel;
    ttl_74x294 dut(.*);
    initial begin
        clk=0;clr_n=0;div_sel=0;#1;clr_n=1;
        for(int code=0;code<=8;code++) begin
            clr_n=0;div_sel=5'(code);#1;clr_n=1;
            for(int cycle=1;cycle<=512;cycle++) begin
                clk=1;#1;
                if(q !== (code<2 ? 1'b0 : 1'((cycle>>(code-1))&1)))
                    $fatal(1,"divide exponent %d, cycle %d",code,cycle);
                clk=0;#1;
            end
        end
        $display("PASS: tb_ttl_74x294 (inhibit and divide ratios)");
        $finish;
    end
endmodule
