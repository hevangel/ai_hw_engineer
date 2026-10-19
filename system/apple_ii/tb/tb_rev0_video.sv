`timescale 1ns/1ps
module tb_rev0_video;
    logic osc=0, reset_n=0;
    logic [15:0] address=0;
    logic rw=1;
    logic [7:0] write_data=0;
    tri [7:0] data;
    tri phi0, video, sync;
    int output_file, sampled=0;
    logic capture=0;
    logic flash=0;
    assign data=rw ? 8'bz : write_data;
    apple_ii_rev0_digital #(.CHAR_ROM("work/char_2513.hex")) dut (
        .master_oscillator(osc),.reset_n(reset_n),.keyboard_data(7'b0),.keyboard_strobe(1'b0),
        .flash(flash),.cassette_in(1'b0),.paddle_timer(4'b0),.buttons(3'b0),
        .cpu_address(address),.cpu_data(data),.cpu_rw(rw),.cpu_phi1(~phi0),.cpu_phi2(phi0),.cpu_sync(1'b0),
        .cpu_phi0(phi0),.cpu_reset_n(),.cpu_irq_n(),.cpu_nmi_n(),.cpu_rdy(),
        .video_data(video),.composite_sync(sync),.speaker(),.cassette_out(),.annunciators(),.paddle_trigger_n()
    );
    tri [5:0] h={dut.D13.p13,dut.D13.p14,dut.D14.p11,dut.D14.p12,dut.D14.p13,dut.D14.p14};
    tri [8:0] v={dut.D11.p11,dut.D11.p12,dut.D11.p13,dut.D11.p14,
                 dut.D12.p11,dut.D12.p12,dut.D12.p13,dut.D12.p14,dut.D13.p11};
    tri [7:0] latched={dut.B8.p7,dut.B8.p5,dut.B8.p12,dut.B8.p10,dut.B5.p7,dut.B5.p5,dut.B5.p12,dut.B5.p10};
    initial forever #34.921 osc=~osc;
    task automatic bus_write(input logic [15:0] a,input logic [7:0] value);
        @(negedge phi0); #10;
        address=a; write_data=value; rw=0;
        @(negedge phi0); #10; rw=1;
    endtask
    task automatic soft_switch(input logic [15:0] a);
        @(negedge phi0); #10; address=a; rw=1;
        @(negedge phi0); #10; address=0;
    endtask
    function automatic logic [15:0] text_address(input int row,input int column,input int page);
        // Manual text-page diagram: eight interleaved groups of three rows.
        return 16'(16'h0400*page+(row%8)*128+(row/8)*40+column);
    endfunction
    function automatic logic [15:0] hires_address(input int y,input int column,input int page);
        // Original interleaved 280x192 address layout; seven dots per byte.
        return 16'(8192*page+(y%8)*1024+((y/8)%8)*128+(y/64)*40+column);
    endfunction
    function automatic logic [7:0] text_pattern(input int row,input int column,input int page);
        logic [7:0] attribute;
        case(column%3)
            0: attribute=0;
            1: attribute=8'h40;
            default: attribute=8'h80;
        endcase
        return attribute | 8'((row*11+column*7+page*13)%64);
    endfunction
    function automatic logic [7:0] hires_pattern(input int y,input int column,input int page);
        return 8'(((y*37+column*19+page*53)%128) | (((y+column+page)%3==0) ? 128:0));
    endfunction
    task automatic frame(input int number);
        do begin @(posedge dut.D14.p2); #25; end while(h!==6'd24 || v!==9'h100);
        output_file=$fopen($sformatf("work/video_%0d.csv",number),"w");
        if(!output_file) $fatal(1,"Cannot open video capture");
        sampled=0; capture=1;
        @(posedge dut.D14.p2); #25;
        do begin @(posedge dut.D14.p2); #25; end while(h!==6'd24 || v!==9'h100);
        capture=0; $fclose(output_file);
        if(sampled!=238944) $fatal(1,"Frame %0d has %0d master samples, expected 912*262",number,sampled);
        $display("CAPTURE digital video frame %0d: %0d master-clock samples",number,sampled);
    endtask
    initial begin
        // ASSUMPTION: same selected legal power-up state as the socket test.
        dut.B1.q=0; dut.C2.q=0;
        dut.D11.q=0; dut.D12.q=0; dut.D13.q=0; dut.D14.q=0;
        #100; reset_n=1;
        repeat(20) @(negedge phi0);
        for(int page=1;page<=2;page++) begin
            for(int row=0;row<24;row++)
                for(int column=0;column<40;column++)
                    bus_write(text_address(row,column,page),text_pattern(row,column,page));
            for(int y=0;y<192;y++)
                for(int column=0;column<40;column++)
                    bus_write(hires_address(y,column,page),hires_pattern(y,column,page));
        end
        soft_switch(16'hc051); // text
        soft_switch(16'hc052); // mixed off
        soft_switch(16'hc054); // page 1
        soft_switch(16'hc056); // hires off
        frame(0);
        flash=1; frame(1);
        flash=0; soft_switch(16'hc055); frame(2); // text page 2
        soft_switch(16'hc050); soft_switch(16'hc054); frame(3); // lores page 1
        soft_switch(16'hc055); soft_switch(16'hc053); frame(4); // mixed lores page 2
        soft_switch(16'hc054); soft_switch(16'hc052); soft_switch(16'hc057); frame(5); // hires page 1
        soft_switch(16'hc055); frame(6); // hires page 2
        soft_switch(16'hc054); soft_switch(16'hc053); frame(7); // mixed hires page 1
        soft_switch(16'hc055); soft_switch(16'hc051); frame(8); // text overrides hires/mixed
        $display("PASS digital video capture timing: nine complete frames");
        $finish;
    end
    initial forever begin
        @(posedge dut.B10.p3); #10;
        if(capture) begin
            $fdisplay(output_file,"%0.3f,%0d,%0d,%b,%b,%h",$realtime,h,v,video,sync,latched);
            sampled++;
        end
    end
    initial begin #400000000; $fatal(1,"Video frame timed out"); end
endmodule
