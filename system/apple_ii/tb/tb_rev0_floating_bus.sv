// Independent phase-boundary observation, not a behavioral memory/I/O model.
`timescale 1ns/1ps
module tb_rev0_floating_bus #(parameter bit RETENTION=1);
    logic osc=0, reset_n=0, rw=1;
    logic [15:0] address=0;
    logic [7:0] write_data=0;
    tri [7:0] data;
    tri phi0;
    logic cassette_in=0;
    logic [2:0] buttons=0;
    logic [3:0] paddles=0;
    assign data=rw ? 8'bz : write_data;
    tri [7:0] expansion_data;
    logic [7:0] expansion_a=8'bz, expansion_b=8'bz;
    assign expansion_data=expansion_a;
    assign expansion_data=expansion_b;
    apple_ii_rev0_digital #(.RETAIN_DATA_BUS(RETENTION)) dut (
        .master_oscillator(osc),.reset_n(reset_n),.keyboard_data(7'h35),.keyboard_strobe(1'b0),
        .flash(1'b0),.cassette_in(cassette_in),.paddle_timer(paddles),.buttons(buttons),
        .cpu_address(address),.cpu_data(data),.system_data_bus(expansion_data),.cpu_rw(rw),.cpu_phi1(~phi0),.cpu_phi2(phi0),.cpu_sync(1'b0),
        .cpu_phi0(phi0),.cpu_reset_n(),.cpu_irq_n(),.cpu_nmi_n(),.cpu_rdy(),
        .video_data(),.composite_sync(),.speaker(),.cassette_out(),.annunciators(),.paddle_trigger_n()
    );
    wire [7:0] system_data=expansion_data; // Resolved slot nets, not mux driver outputs.
    tri [7:0] video_latch={dut.B8.p7,dut.B8.p5,dut.B8.p12,dut.B8.p10,
                          dut.B5.p7,dut.B5.p5,dut.B5.p12,dut.B5.p10};
    tri [5:0] h={dut.D13.p13,dut.D13.p14,dut.D14.p11,dut.D14.p12,dut.D14.p13,dut.D14.p14};
    tri [8:0] v={dut.D11.p11,dut.D11.p12,dut.D11.p13,dut.D11.p14,
                 dut.D12.p11,dut.D12.p12,dut.D12.p13,dut.D12.p14,dut.D13.p11};
    initial forever #34.921 osc=~osc;
    task automatic bus_write(input logic [15:0] a,input logic [7:0] value);
        @(negedge phi0); #10; address=a; write_data=value; rw=0;
        @(negedge phi0); #10; rw=1;
    endtask
    task automatic select_address(input logic [15:0] a);
        @(negedge phi0); #10; address=a;
    endtask
    // All 256 byte values occur in each 1K page. Memory is written via pins.
    function automatic logic [7:0] pattern(input logic [15:0] a);
        return a[7:0] ^ 8'(a[9:8]*53);
    endfunction
    logic [7:0] preceding_video;
    logic [7:0] expected;
    integer checked=0, changed=0;
    task automatic check_reads(input logic [15:0] a,input bit partial,input logic bit7);
        select_address(a);
        repeat(512) begin
            @(posedge phi0);
            preceding_video=system_data;
            if(system_data!==video_latch) $fatal(1,"Video phase not driven by real latch");
            if(!$isunknown(preceding_video)) begin
                expected=partial ? {bit7,preceding_video[6:0]} : preceding_video;
                @(negedge phi0);
                if(data!==expected || system_data!==expected)
                    $fatal(1,"Floating read %h: CPU=%h system=%h preceding video=%h expected=%h",a,data,system_data,preceding_video,expected);
                checked++;
                if(preceding_video!=8'hff && preceding_video!=8'h00) changed++;
            end else @(negedge phi0);
        end
    endtask
    initial begin
        // ASSUMPTION: a selected legal startup state, no invented board reset.
        dut.B1.q=0; dut.C2.q=0;
        dut.D11.q=0; dut.D12.q=0; dut.D13.q=0; dut.D14.q=0;
        dut.B10.q1=0; dut.B10.n1=1;
        #100; reset_n=1;
        repeat(20) @(negedge phi0);
        for(int a=16'h0400;a<16'h0800;a++) bus_write(16'(a),pattern(16'(a)));
        // Rev-0 blanking fetches can select A12 too; initialize through pins.
        for(int a=16'h1400;a<16'h1800;a++) bus_write(16'(a),pattern(16'(a)));
        select_address(16'hc051); select_address(16'hc052); select_address(16'hc054);
        check_reads(16'hc020,0,0);
        check_reads(16'hc030,0,0);
        check_reads(16'hc040,0,0);
        check_reads(16'hc058,0,0);
        check_reads(16'hc070,0,0);
        check_reads(16'hc060,1,0);
        cassette_in=1; check_reads(16'hc060,1,1);
        check_reads(16'hc061,1,0);
        buttons=3'b001; check_reads(16'hc061,1,1);
        check_reads(16'hc064,1,0);
        paddles=4'b0001; check_reads(16'hc064,1,1);
        // An expansion card drives the physical slot data nets. Pause in I/O
        // phi2 after B6/B7 release; check passive charge cannot mask contention.
        select_address(16'hc040);
        @(posedge phi0); #100;
        force osc=0;
        expansion_a=8'h5a; #50;
        if(data!==8'h5a) $fatal(1,"Strong slot data did not replace retained charge");
        expansion_a=8'bz; #50;
        if(data!==8'h5a) $fatal(1,"Slot charge was not retained");
        reset_n=0; #50; reset_n=1; #50;
        if(data!==8'h5a) $fatal(1,"CPU RES incorrectly cleared bus charge");
        expansion_a=8'h5a; expansion_b=8'ha5; #50;
        if(data!==8'hxx) $fatal(1,"Retained charge hid strong bus contention: %h",data);
        expansion_a=8'bz; expansion_b=8'bz; #50;
        if(data!==8'hxx) $fatal(1,"Contention did not invalidate charge");
        expansion_a=8'h3c; #50; expansion_a=8'bz; #50;
        if(data!==8'h3c) $fatal(1,"Known drive did not restore charge");
        release osc;
        bus_write(16'h0300,8'ha5);
        select_address(16'h0300);
        repeat(3) @(posedge phi0);
        @(negedge phi0);
        if(data!==8'ha5) $fatal(1,"Retained video overrode strong RAM read");
        if(checked<3000 || changed<2000) $fatal(1,"Insufficient known nontrivial floating reads %0d/%0d",checked,changed);
        $display("PASS physical floating data bus: %0d known reads, %0d nontrivial video bytes, cassette/buttons/paddles D7, strong CPU write and RAM read",checked,changed);
        $finish;
    end
    initial begin #30000000; $fatal(1,"Floating bus test timeout"); end
endmodule
