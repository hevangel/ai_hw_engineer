`timescale 1ns/1ps
module tb_ttl_74x818;
    logic [7:0] d_bus_in,y_bus_in,d_out,y_out,external_d,external_y;
    logic [7:0] expected_s,expected_p;
    logic dclk,pclk,mode,sdi,oe_y_n,d_drive,y_drive,sdo,expected_drive;
    ttl_74x818 dut(.*);
    assign d_bus_in=d_drive?d_out:external_d;
    assign y_bus_in=y_drive?y_out:external_y;
    task automatic check;
        #1;
        if(d_drive!==expected_drive || y_drive!==!oe_y_n ||
           d_out!==(expected_drive?expected_s:8'd0) ||
           y_out!==(!oe_y_n?expected_p:8'd0) || sdo!==(mode?sdi:expected_s[7]))
            $fatal(1,"diagnostic/pipeline/registered enable/serial contract");
    endtask
    task automatic diag_edge;
        dclk=0;#1;
        if(!mode) expected_s={expected_s[6:0],sdi};
        else if(!sdi) expected_s=y_bus_in;
        expected_drive=mode && sdi;
        dclk=1;check;dclk=0;check;
    endtask
    task automatic pipe_edge;
        pclk=0;#1;expected_p=mode?expected_s:d_bus_in;
        pclk=1;check;pclk=0;check;
    endtask
    task automatic both_edges;
        logic [7:0] old_s,old_y,old_d;
        dclk=0;pclk=0;#1;old_s=expected_s;old_y=y_bus_in;old_d=d_bus_in;
        expected_p=mode?old_s:old_d;
        if(!mode) expected_s={old_s[6:0],sdi};
        else if(!sdi) expected_s=old_y;
        expected_drive=mode && sdi;
        dclk=1;pclk=1;check;dclk=0;pclk=0;check;
    endtask
    initial begin
        dclk=0;pclk=0;mode=0;sdi=0;oe_y_n=0;external_d=0;external_y=0;
        expected_s=0;expected_p=0;expected_drive=0;
        // Disable the D driver first, then initialize P and capture known Y in S.
        #1;dclk=1;#1;dclk=0;pclk=1;#1;pclk=0;mode=1;
        #1;dclk=1;#1;dclk=0;check;
        for(int pattern=0;pattern<256;pattern++) begin
            mode=0;
            for(int bit_number=0;bit_number<8;bit_number++) begin
                sdi=(8'(pattern)>>(7-bit_number))&1'b1;diag_edge;
            end
            external_d=8'(pattern*37+11);pipe_edge;
            mode=1;sdi=1;check; // enable must not change until DCLK
            diag_edge;pipe_edge;
            mode=0;sdi=0;check; // registered D drive still active
            mode=1;oe_y_n=1;external_y=8'(~pattern);sdi=0;diag_edge;
            pipe_edge;oe_y_n=0;check;
            external_y=8'(pattern);both_edges; // parallel register swap
            mode=0;sdi=1;external_d=8'(pattern*19+5);both_edges;
        end
        $display("PASS: tb_ttl_74x818");$finish;
    end
endmodule
