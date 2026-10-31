`timescale 1ns/1ps
module tb_ttl_74x757;
    logic [7:0] a,y,expected,data_value;
    logic oe1_n,oe2;
    ttl_74x757 dut(.*);
    initial begin
        for(int enables=0;enables<4;enables++) begin
            oe1_n=enables[0];oe2=enables[1];
            for(int i=0;i<256;i++) begin
                a=8'(i);data_value=a;
                expected[3:0]=oe1_n?4'hf:data_value[3:0];
                expected[7:4]=!oe2?4'hf:data_value[7:4];#1;
                if(y!==expected) $fatal(1,"open collector enable/release");
            end
        end
        $display("PASS: tb_ttl_74x757");$finish;
    end
endmodule
