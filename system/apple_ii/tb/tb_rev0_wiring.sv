`timescale 1ns/1ps
module tb_rev0_wiring;
    logic osc = 0;
    logic reset_n = 0;
    logic [15:0] address = 16'h0200;
    logic rw = 1;
    logic [7:0] write_data = 8'h5a;
    tri [7:0] data;
    tri phi0;
    tri cpu_reset_n, cpu_irq_n, cpu_nmi_n, cpu_rdy;
    tri video_data, composite_sync, speaker, cassette_out, paddle_trigger_n;
    tri [3:0] annunciators;
    int cpu_edges = 0;
    assign data = rw ? 8'bz : write_data;
    apple_ii_rev0_digital dut (
        .master_oscillator(osc), .reset_n(reset_n),
        .keyboard_data(7'h41), .keyboard_strobe(1'b0),
        .flash(1'b0), .cassette_in(1'b0), .paddle_timer(4'b0), .buttons(3'b0),
        .cpu_address(address), .cpu_data(data), .cpu_rw(rw),
        .cpu_phi1(~phi0), .cpu_phi2(phi0), .cpu_sync(1'b0),
        .cpu_phi0(phi0), .cpu_reset_n(cpu_reset_n), .cpu_irq_n(cpu_irq_n),
        .cpu_nmi_n(cpu_nmi_n), .cpu_rdy(cpu_rdy), .video_data(video_data),
        .composite_sync(composite_sync), .speaker(speaker), .cassette_out(cassette_out),
        .annunciators(annunciators), .paddle_trigger_n(paddle_trigger_n)
    );
    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc = ~osc; end
    // ASSUMPTION: one legal power-up state is selected explicitly by this
    // diagnostic harness. The motherboard contains no artificial reset wire.
    initial begin
        dut.B1.q=0; dut.C2.q=0;
        dut.D11.q=0; dut.D12.q=0; dut.D13.q=0; dut.D14.q=0;
        #100;
        if ({cpu_reset_n,cpu_irq_n,cpu_nmi_n,cpu_rdy} !== 4'b0111)
            $fatal(1,"CPU socket reset/pull-ups");
        reset_n=1;
        #100;
        if (cpu_reset_n !== 1) $fatal(1,"reset release");
        repeat (20) @(negedge phi0);
        // Socket bus master writes and reads through the real buffer/mux/DRAM
        // topology. No behavioral RAM or decoder appears in this test.
        for (int i=0;i<3;i++) begin
            address=16'(16'h0200+16'h4000*i);
            write_data=8'(8'h5a+i); rw=0;
            @(posedge phi0); #300;
            $display("WRITE D=%h H10en=%b bus=%b sysD=%b C3DI=%b WE=%b",data,dut.H10.p1,dut.H10.p3,dut.H10.p2,dut.C3.p2,dut.C3.p3);
            repeat(2) @(negedge phi0);
            #10; rw=1;
            repeat(2) @(posedge phi0);
            #470;
            if(data !== 8'(8'h5a+i)) begin
                $display("phi %b rw %b cpuD %h H10: en %b/%b bus %b rx %b",phi0,rw,data,dut.H10.p1,dut.H10.p15,dut.H10.p3,dut.H10.p2);
                $display("DRAM C3 ras %b cas %b we %b row %h col %h DO %b C2 %h B1 %h",dut.C3.p4,dut.C3.p15,dut.C3.p3,dut.C3.row,dut.C3.column,dut.C3.p14,dut.C2.q,dut.B1.q);
                $display("C3 active/read %b/%b power %b B6 sel/oe %b/%b LD %b DO %b dataout %b",dut.C3.cas_active,dut.C3.read_cycle,dut.C3.powered,dut.B6.p1,dut.B6.p15,dut.B6.p10,dut.B6.p9,dut.C3.data_out);
                $fatal(1,"RAM row %0d read %h",i,data);
            end
            @(negedge phi0); #10;
        end
        $display("PASS revision-0 socket wiring and three physical DRAM banks");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Board clock failed to start or socket transaction hung");
    end
endmodule
