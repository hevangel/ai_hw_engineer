`timescale 1ns/1ps
module tb_ttl_74x209;
    logic clk,we_n,cs_n;
    logic [9:0] addr;
    logic [0:0] data_in,data_out;
    logic [0:0] drive_en;
    ttl_74x209 dut(.*);
    function automatic logic [0:0] pattern(input int address,pass);
        return 1'((address*13)^((address>>3)*7)^(pass*29));
    endfunction
    task automatic tick;clk=0;#1;clk=1;#1;clk=0;#1;endtask
    initial begin
        clk=0;we_n=1;cs_n=1;addr=0;data_in=0;#1;
        for(int pass=0;pass<3;pass++) begin
            cs_n=0;we_n=0;
            for(int address=0;address<1024;address++) begin
                addr=10'(address);data_in=pattern(address,pass);tick;
            end
            we_n=1;
            for(int reverse_index=0;reverse_index<=1023;reverse_index++) begin
                int address;address=1023-reverse_index;
                addr=10'(address);#1;
                if(data_out !== pattern(address,pass))
                    $fatal(1,"memory alias or inversion address=%d pass=%d",address,pass);
                if(drive_en !== 1'('1)) $fatal(1,"read drive disabled");
            end
            // No write when WE is inactive or chip select is inactive.
            addr=0;data_in=~pattern(0,pass);tick;
            if(data_out !== pattern(0,pass)) $fatal(1,"inactive WE wrote");
            cs_n=1;we_n=0;tick;cs_n=0;we_n=1;#1;
            if(data_out !== pattern(0,pass)) $fatal(1,"inactive CS wrote");
        end
        $display("PASS: tb_ttl_74x209 (all 1024 addresses, three patterns, write gating)");
        $finish;
    end
endmodule
