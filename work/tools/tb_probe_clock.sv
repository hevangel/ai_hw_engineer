`timescale 1ns/1ps
module tb_probe_clock;
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
    initial begin #2000; forever #34.921 osc = ~osc; end
    initial begin
        dut.B1.q=0; dut.C2.q=0;
        dut.D11.q=0; dut.D12.q=0; dut.D13.q=0; dut.D14.q=0;
        #100 reset_n=1;
        repeat (24) @(negedge osc)
            $display("%0t osc=%b phi0=%b reset=%b B1q=%b", $realtime, osc, phi0,
                     cpu_reset_n, dut.B1.q);
        $finish;
    end
endmodule
