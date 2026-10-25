`timescale 1ns/1ps
module tb_ttl_74x438;
    logic [7:0] status;
    logic dbin,wr_n,hlda,mem_r_n,mem_w_n,io_r_n,io_w_n,inta_n;
    ttl_74x438 dut(.*);
    initial begin
        for(int flags=0;flags<256;flags++) begin
            status=8'(flags);
            for(int controls=0;controls<8;controls++) begin
                dbin=controls[0];wr_n=controls[1];hlda=controls[2];#1;
                if(mem_r_n!==!(status[7] && dbin && !hlda) ||
                   mem_w_n!==!(!status[1] && !status[3] && !wr_n && !hlda) ||
                   io_r_n!==!(status[6] && dbin && !hlda) ||
                   io_w_n!==!(status[3] && !wr_n && !hlda) ||
                   inta_n!==!(status[0] && dbin && !hlda)) $fatal(1,"status/ownership decode");
            end
        end
        $display("PASS: tb_ttl_74x438");$finish;
    end
endmodule
