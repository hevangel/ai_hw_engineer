`timescale 1ns/1ps
module tb_ttl_74x2414;
    logic [1:0] address_1,address_2;
    logic supply_good,sd_n,g_n,g1_n,g2;
    logic [3:0] y1_n,y2_n;
    logic vs,vs_drive_low;
    ttl_74x2414 dut(.*);
    initial begin
        for(int v=0;v<512;v++) begin
            {supply_good,sd_n,g_n,g1_n,g2,address_1,address_2}=9'(v);
            #1;
            for(int n=0;n<4;n++) begin
                if(y1_n[n] !== !(supply_good && sd_n && !g_n && !g1_n && int'(address_1)==n))
                    $fatal(1,"first bank decoder truth table");
                if(y2_n[n] !== !(supply_good && sd_n && !g_n && g2 && int'(address_2)==n))
                    $fatal(1,"second bank decoder truth table");
            end
            if(vs!==!supply_good || vs_drive_low!==supply_good)
                $fatal(1,"independent open-collector supply monitor");
        end
        $display("PASS: tb_ttl_74x2414");$finish;
    end
endmodule
