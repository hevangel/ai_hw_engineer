`timescale 1ns/1ps
module tb_ttl_74x187;
    logic [7:0] addr;
    logic [3:0] data;

    ttl_74x187 #(.INIT_FILE("tb/data/rom_187.hex")) dut(.*);
    initial begin

        for(int i=0;i<256;i++) begin
            addr=8'(i);#1;
            if(data !== 4'((i*73)^(i<<4)^32'ha5)) $fatal(1,"ROM image/address %d",i);
        end

        $display("PASS: tb_ttl_74x187 (loaded image, all 256 addresses, read-only interface)");
        $finish;
    end
endmodule
