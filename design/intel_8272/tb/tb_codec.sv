`timescale 1ns/1ps
module tb_codec;
    logic clk=0;
    initial forever #5 clk=~clk;
    logic rst_n=0, clear=0, byte_valid=0;
    logic [7:0] data=0;
    logic [15:0] crc;
    intel_8272_crc crc_dut(.*);
    logic mfm=0, previous_data=0;
    logic [7:0] data_in=0,decoded;
    logic [1:0] mark=0;
    logic [15:0] encoded,encoded_in=0;
    logic next_data,missing_clock;
    intel_8272_codec codec_dut(.*);
    logic [31:0] vectors[0:1023];
    string filename;
    integer checks=0;
    task automatic check(input bit ok,input string message);
        checks++; if (!ok) $fatal(1,"%s",message);
    endtask
    task automatic put(input logic [7:0] value);
        @(negedge clk); byte_valid=1; data=value;
        @(negedge clk); byte_valid=0;
    endtask
    initial begin
        if (!$value$plusargs("vectors=%s",filename)) $fatal(1,"vectors path required");
        $readmemh(filename,vectors);
        for (integer k=0;k<1024;k++) begin
            mfm=vectors[k][28]; previous_data=vectors[k][24]; data_in=vectors[k][23:16];
            encoded_in=vectors[k][15:0]; #1;
            check(encoded==encoded_in,"Greaseweazle encoding vector");
            check(decoded==data_in,"decode vector"); check(next_data==data_in[0],"last data bit");
            check(!missing_clock,"normal word clock");
        end
        mfm=1; mark=1; encoded_in=16'h4489; #1;
        check(encoded==16'h4489 && decoded==8'ha1 && missing_clock,"MFM A1");
        mark=2; encoded_in=16'h5224; #1;
        check(encoded==16'h5224 && decoded==8'hc2 && missing_clock,"MFM C2");
        mfm=0; mark=3; data_in=8'hfe; encoded_in=16'hf57e; #1;
        check(encoded==16'hf57e && decoded==8'hfe && missing_clock,"FM FE clock C7");
        @(negedge clk); rst_n=1;
        for (integer k=0;k<9;k++) put(8'(8'h31+k));
        check(crc==16'h29b1,"CRC 123456789 known answer");
        put(8'h29); put(8'hb1); check(crc==0,"CRC residue");
        @(negedge clk); clear=1; @(negedge clk); clear=0;
        put(8'ha1); put(8'ha1); put(8'ha1); put(8'hfe);
        put(3); put(0); put(1); put(2);
        check(crc==16'h51b3,"CRC IBM ID vector");
        $display("8272 CODEC PASSED checks=%0d",checks); $finish;
    end
endmodule
