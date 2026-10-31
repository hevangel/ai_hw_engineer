`timescale 1ns/1ps
// Negative control for the refresh checker: the same board with an idle CPU
// socket, so the video scan is the only refresh source. The checker must report
// the gaps it measures (and its violations) here, proving it is not stuck at
// zero when the boot run reports none.
module tb_refresh_video_only;
    logic osc = 0;
    logic reset_n = 0;
    tri [7:0] data;
    tri phi0;
    tri cpu_reset_n, cpu_irq_n, cpu_nmi_n, cpu_rdy;
    tri video_data, composite_sync, speaker, cassette_out, paddle_trigger_n;
    tri [3:0] annunciators;
    apple_ii_rev0_digital dut (
        .master_oscillator(osc), .reset_n(reset_n),
        .keyboard_data(7'h41), .keyboard_strobe(1'b0),
        .flash(1'b0), .cassette_in(1'b0), .paddle_timer(4'b0), .buttons(3'b0),
        .cpu_address(16'h0200), .cpu_data(data), .cpu_rw(1'b1),
        .cpu_phi1(~phi0), .cpu_phi2(phi0), .cpu_sync(1'b0),
        .cpu_phi0(phi0), .cpu_reset_n(cpu_reset_n), .cpu_irq_n(cpu_irq_n),
        .cpu_nmi_n(cpu_nmi_n), .cpu_rdy(cpu_rdy), .video_data(video_data),
        .composite_sync(composite_sync), .speaker(speaker), .cassette_out(cassette_out),
        .annunciators(annunciators), .paddle_trigger_n(paddle_trigger_n)
    );
    apple_ii_refresh_check refresh_check (
        .ras_n(dut.C3.p4),
        .row_addr({dut.C3.p13, dut.C3.p5, dut.C3.p6, dut.C3.p7,
                   dut.C3.p12, dut.C3.p11, dut.C3.p10})
    );
    initial begin #2000; forever #34.921 osc = ~osc; end
    initial begin
        dut.B1.q=0; dut.C2.q=0;
        dut.D11.q=0; dut.D12.q=0; dut.D13.q=0; dut.D14.q=0;
        #100; reset_n=1;
        #40000000;                   // 40 ms: several refresh sweeps
        $display("VIDEO-ONLY rows=%0d accesses=%0d worst_gap=%0t violations_over_2ms=%0d",
                 refresh_check.rows_seen, refresh_check.accesses,
                 refresh_check.worst, refresh_check.violations);
        if (refresh_check.rows_seen != 128) $fatal(1,"video scan did not cover all rows");
        if (refresh_check.violations == 0) $fatal(1,"checker did not flag the video-only margin");
        $finish;
    end
endmodule
