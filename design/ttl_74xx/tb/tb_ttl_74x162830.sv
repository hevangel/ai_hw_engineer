`timescale 1ns/1ps
module tb_ttl_74x162830;
    logic [17:0] a,y1,y2;
    logic [1:0] oe_n,drive;
    ttl_74x162830 dut(.*);
    initial begin
        for(int control=0;control<4;control++) begin
            oe_n=2'(control);
            for(int i=0;i<512;i++) begin
                a=18'(i*701+15);#1;
                if(drive!==~oe_n || y1!==(oe_n[0]?18'd0:a) || y2!==(oe_n[1]?18'd0:a))
                    $fatal(1,"independent address fanout enables");
            end
        end
        $display("PASS: tb_ttl_74x162830");$finish;
    end
endmodule
