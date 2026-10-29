`timescale 1ns/1ps
module tb_ttl_74x288;
    logic [4:0] addr;
    logic [7:0] data_out;
    logic cs_n; logic [7:0] drive_en;
    ttl_74x288 #(.INIT_FILE("tb/data/rom_288.hex")) dut(.*);
    initial begin
        cs_n=0;
        for(int i=0;i<32;i++) begin
            addr=5'(i);#1;
            if(data_out !== 8'((i*73)^(i<<4)^32'ha5)) $fatal(1,"ROM image/address %d",i);
        end
        cs_n=1;#1;if(drive_en!==0 || data_out!==0)$fatal(1,"ROM output disable");
        $display("PASS: tb_ttl_74x288 (loaded image, all 32 addresses, read-only interface)");
        $finish;
    end
endmodule
