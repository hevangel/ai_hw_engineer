`timescale 1ns/1ps
module tb_ttl_74x952;
    logic [7:0] io_in,io_out,expected_a,expected_b;
    logic clk,serial_in,dis_o,dis_i,dis_tu,dis_td,dis_s,io_drive,serial_out;
    ttl_74x952 dut(.*);
    task automatic check;
        #1;
        if(io_drive!==(dis_i && !dis_o) ||
           io_out!==((dis_i && !dis_o)?expected_a:8'd0) || serial_out!==expected_b[7])
            $fatal(1,"native bus direction, A readback or B serial order");
    endtask
    task automatic step;
        logic [7:0] old_a,old_b;
        clk=0;#1;old_a=expected_a;old_b=expected_b;
        // Independent per-bit table interpretation, using explicit transfers.
        for(int n=0;n<8;n++) begin
            if(!dis_tu && !dis_td) begin
                expected_a[n]=dis_i?1'b0:io_in[n];expected_b[n]=0;
            end else begin
                if(!dis_tu) expected_a[n]=old_b[n] | (!dis_i && io_in[n]);
                else if(!dis_i) expected_a[n]=io_in[n];
                if(!dis_td) expected_b[n]=dis_i?old_a[n]:io_in[n];
                else if(!dis_s) expected_b[n]=(n==0)?serial_in:old_b[n-1];
            end
        end
        clk=1;check;clk=0;check;
    endtask
    initial begin
        clk=0;serial_in=0;io_in=0;dis_o=1;dis_i=1;dis_tu=0;dis_td=0;dis_s=1;
        expected_a=0;expected_b=0;#1;clk=1;#1;clk=0;check;
        for(int controls=0;controls<32;controls++) begin
            for(int data_pattern=0;data_pattern<128;data_pattern++) begin
                for(int serial_value=0;serial_value<2;serial_value++) begin
                    // Seed B and A separately through native parallel operations.
                    dis_i=0;dis_o=1;dis_tu=1;dis_td=0;dis_s=1;
                    io_in=8'(data_pattern*13+67);step;
                    dis_td=1;io_in=8'(data_pattern*37+19);step;
                    {dis_o,dis_i,dis_tu,dis_td,dis_s}=5'(controls);
                    serial_in=1'(serial_value);io_in=8'(data_pattern*23+131);check;step;
                    // Observe A directly, then transfer the whole hidden B rank to A.
                    dis_i=1;dis_o=0;dis_tu=1;dis_td=1;dis_s=1;check;
                    dis_tu=0;step;
                end
            end
        end
        $display("PASS: tb_ttl_74x952");$finish;
    end
endmodule
