`timescale 1ns/1ps
module tb_ttl_74x186;
    logic [5:0] addr;
    logic [7:0] data;

    ttl_74x186 #(.INIT_FILE("tb/data/rom_186.hex")) dut(.*);
    initial begin

        for(int i=0;i<64;i++) begin
            addr=6'(i);#1;
            if(data !== 8'((i*73)^(i<<4)^32'ha5)) $fatal(1,"ROM image/address %d",i);
        end

        $display("PASS: tb_ttl_74x186 (loaded image, all 64 addresses, read-only interface)");
        $finish;
    end
endmodule
