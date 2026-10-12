// Apple IIe PAL self-checking testbench.
//
// The reference model is an independent encoding of spec/spec.md: an
// explicit 14-entry truth table per output (the RTL uses arithmetic
// compares on the next-tick decode). After every committing edge the
// model advances and the DUT outputs for the new window are compared.

`timescale 1ns/1ps

module tb_top;

    localparam int TCK = 70;   // ~14M period

    logic clk14 = 1'b0;
    always #(TCK/2) clk14 = ~clk14;

    logic       rst_n;
    logic       m7;
    logic       ramen_n;
    logic       s80vid_n;
    logic       entmg_n;
    wire        ldps_n, vid7m, phi1, phi0, q3, pcas_n, pras_n;

    apple_iie_pal dut (
        .clk14, .rst_n,
        .m7,
        .ramen_n, .s80vid_n, .entmg_n,
        .ldps_n, .vid7m, .phi1, .phi0, .q3, .pcas_n, .pras_n
    );

    int checks = 0;
    int errors = 0;

    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) begin
            errors++;
            $display("CHECK FAILED [%s] at %0t: tick=%0d phi0=%b phi1=%b q3=%b pras=%b pcas=%b ldps=%b vid7m=%b ramen=%b s80=%b entmg=%b",
                     what, $time, dut.tick_q, phi0, phi1, q3, pras_n, pcas_n,
                     ldps_n, vid7m, ramen_n, s80vid_n, entmg_n);
        end
    endtask

    // ------------------------------------------------------------------
    // Reference model: explicit 14-entry tables (spec 4). m_tick is the
    // window the DUT (and model) are currently IN.
    // ------------------------------------------------------------------
    int   m_tick = 0;
    logic m_ramen_sample;

    function automatic bit f_phi0(input int t);
        return (t < 7);
    endfunction
    function automatic bit f_q3(input int t);
        return (((t >= 7) ? t - 7 : t) < 4);
    endfunction
    function automatic bit f_prasn(input int t);
        return (t < 4);
    endfunction
    function automatic bit f_pcasn(input int t, input bit gated);
        if (t <= 5 || t == 13) return 1'b1;
        return gated;                     // ticks 6-12
    endfunction
    function automatic bit f_ldpsn(input int t, input bit s80n);
        return !((t == 13) || ((t == 6) && !s80n));
    endfunction

    task automatic m_reset_state;
        m_tick = 0;
        m_ramen_sample = 1'b0;
    endtask

    // Advance the model into the next window (called just after the edge).
    task automatic m_step(input bit run_i);
        if (!run_i) begin
            m_reset_state();
            return;
        end
        if (m_tick == 4) m_ramen_sample = ramen_n;   // sampled entering 5
        m_tick = (m_tick == 13) ? 0 : m_tick + 1;
        if (m_tick == 0) m_ramen_sample = 1'b0;
    endtask

    // Check the DUT's current window against the model.
    task automatic m_check(input bit run_i, input bit m7_prev);
        if (!run_i) begin
            check(phi0 == 1'b0, "idle phi0");
            check(phi1 == 1'b1, "idle phi1");
            check(q3 == 1'b0, "idle q3");
            check(pras_n == 1'b1, "idle pras");
            check(pcas_n == 1'b1, "idle pcas");
            check(ldps_n == 1'b1, "idle ldps");
            check(vid7m == 1'b0, "idle vid7m");
        end else begin
            check(phi0 == f_phi0(m_tick), "phi0");
            check(phi1 == !f_phi0(m_tick), "phi1");
            check(q3 == f_q3(m_tick), "q3");
            check(pras_n == f_prasn(m_tick), "pras");
            check(pcas_n == f_pcasn(m_tick, m_ramen_sample), "pcas");
            check(ldps_n == f_ldpsn(m_tick, s80vid_n), "ldps");
            check(vid7m == m7_prev, "vid7m");   // 7M delayed one tick
        end
    endtask

    logic m7_prev = 1'b0;    // m7 as seen by the last committing edge
    bit  run_eff;

    // One 14M tick with the given inputs: commit edge, model step, check.
    task automatic tick_it(input bit run_i, input bit m7_i);
        @(negedge clk14);
        run_eff = run_i && rst_n && entmg_n;   // the enable the DUT sees
        m7      = m7_i;
        @(posedge clk14);
        m_step(run_eff);
        m7_prev = m7_i;
        #(TCK/4);
        m_check(run_eff, m7_prev);
    endtask

    task automatic reset_chip;
        @(negedge clk14);
        rst_n = 1'b0; entmg_n = 1'b1;
        ramen_n = 1'b1; s80vid_n = 1'b1; m7 = 1'b0;
        repeat (2) @(posedge clk14);
        @(negedge clk14);
        rst_n = 1'b1;
        m_reset_state();
        m7_prev = 1'b0;
        #(TCK/4);
        m_check(1'b0, 1'b0);   // reset-idle pattern
    endtask

    int i;

    initial begin
        reset_chip();

        // 1. Idle under ENTMG disabled (spec 4.4, A6)
        entmg_n = 1'b0;
        repeat (5) tick_it(1'b1, 1'b0);   // run_i ignored: entmg gates
        check(dut.tick_q == 4'd0, "held tick");
        entmg_n = 1'b1;

        // 2. Two full 40-column RAM cycles (spec 4)
        ramen_n = 1'b0;                   // 0 = RAM enabled: CAS falls
        s80vid_n = 1'b1;
        repeat (28) tick_it(1'b1, 1'($urandom_range(0, 1)));

        // 3. Non-RAM cycles: PCAS' held high through ticks 6-12 (spec 4.2)
        ramen_n = 1'b1;
        repeat (14) tick_it(1'b1, 1'b0);
        ramen_n = 1'b0;
        repeat (14) tick_it(1'b1, 1'b0);

        // 4. 80-column cadence: two LDPS' pulses per cycle (spec 4.3, A4)
        s80vid_n = 1'b0;
        repeat (14) tick_it(1'b1, 1'b0);
        s80vid_n = 1'b1;
        repeat (14) tick_it(1'b1, 1'b0);

        // 5. Random soak: random gating/cadence/7M, occasional ENTMG drop
        for (i = 0; i < 6000; i++) begin
            if (32'($urandom_range(0, 499)) == 0) begin
                entmg_n = 1'b0;
                repeat (4) tick_it(1'b1, 1'($urandom_range(0, 1)));
                entmg_n = 1'b1;
                // model and DUT are both parked at tick 0; the next
                // committing edge resumes them in lockstep
            end
            ramen_n  = 1'($urandom_range(0, 3) != 0);
            s80vid_n = 1'($urandom_range(0, 3) != 0);
            tick_it(1'b1, 1'($urandom_range(0, 1)));
        end

        if (errors == 0)
            $display("Apple IIe PAL TEST PASSED checks=%0d", checks);
        else
            $fatal(1, "Apple IIe PAL TEST FAILED errors=%0d checks=%0d", errors, checks);
        $finish;
    end

    // Watchdog
    initial begin
        #20_000_000;
        $fatal(1, "Apple IIe PAL TEST TIMEOUT");
    end
endmodule
