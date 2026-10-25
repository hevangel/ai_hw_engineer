`timescale 1ns/1ps
module tb_ttl_74x817;
    logic ai,bi,oeab_n,oeba_n,bo_drive,ao_drive;
    logic [1:0] bo;logic [5:0] ao;
    ttl_74x817 dut(.*);
    initial begin
        for(int vector=0;vector<16;vector++) begin
            {ai,bi,oeab_n,oeba_n}=4'(vector);#1;
            if(bo_drive!==!oeab_n || ao_drive!==!oeba_n || bo!==(oeab_n?2'd0:(ai?2'd0:2'd3)) ||
               ao!==(oeba_n?6'd0:(bi?6'd0:6'd63))) $fatal(1,"inverting independent fanout");
        end
        $display("PASS: tb_ttl_74x817");$finish;
    end
endmodule
