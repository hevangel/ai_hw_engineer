// Apple IIe PAL formal properties.
// Included inside apple_iie_pal.sv under `ifdef FORMAL. Immediate asserts in
// clocked blocks only. Expected values are restated from spec/spec.md (TRM
// Tables 7-5/7-8/7-10, Figure 7-1 segment decomposition, ch.2/ch.7 LDPS'
// cadence) with independent encodings, not copied from the RTL.

`ifdef FORMAL

logic f_past_valid;
initial f_past_valid = 1'b0;

// Shadows for transition checks.
logic [3:0] f_tick_d;
logic       f_run_d;
logic       f_ramen_d, f_m7_d;
always_ff @(posedge clk14) begin
    f_tick_d  <= tick_q;
    f_run_d   <= run;
    f_ramen_d <= ramen_n;
    f_m7_d    <= m7;
end

// Independent tick-7 reduce (explicit subtract, not the RTL's compare form).
function automatic logic [2:0] f_t7(input logic [3:0] t);
    f_t7 = (t >= 4'd7) ? (t - 4'd7) : t[2:0];
endfunction

always_ff @(posedge clk14) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) assume(!rst_n);

    // Inside always_ff all reads are pre-edge: the state visible here was
    // committed at the previous edge sampling inputs at that edge, so the
    // branch selector is f_run_d (the commit-edge enable), not `run`.
    if (f_past_valid && f_run_d) begin
        // ---- counter (spec 4) ----
        assert(tick_q == ((f_tick_d == 4'd13) ? 4'd0 : f_tick_d + 4'd1));

        // ---- CPU clocks (spec 4.1): outputs decode the current window ----
        assert(phi0 == (tick_q < 4'd7));
        assert(phi1 == !phi0);
        assert(q3  == (f_t7(tick_q) < 3'd4));
        // Q3 falls at ticks 4 and 11, rises at 7 and 0.
        if (tick_q == 4'd4 || tick_q == 4'd11)  assert(!q3 && $past(q3));
        if (tick_q == 4'd7 || tick_q == 4'd0)   assert(q3 && !$past(q3));

        // ---- PRAS' (spec 4.2): high ticks 0-3; falls at 4 with Q3 ----
        assert(pras_n == (tick_q < 4'd4));
        if (tick_q == 4'd4)
            assert(!pras_n && !q3 && $past(pras_n) && $past(q3));

        // ---- PCAS' (spec 4.2, A7) ----
        if (tick_q <= 4'd5 || tick_q == 4'd13) assert(pcas_n);
        else assert(pcas_n == cas_gated_q);        // ticks 6-12; 1 = gated
        // the RAMEN' sample commits entering tick 5
        if (f_tick_d == 4'd4)
            assert(cas_gated_q == f_ramen_d);
        // a gated cycle never asserts CAS
        if (cas_gated_q && tick_q >= 4'd6 && tick_q <= 4'd12)
            assert(pcas_n);

        // ---- LDPS' (spec 4.3, A4). The cadence input is sampled at the
        // committing edge, so the window invariant uses its $past value.
        if (tick_q == 4'd13 || (tick_q == 4'd6 && !$past(s80vid_n)))
            assert(!ldps_n);
        else
            assert(ldps_n);

        // ---- VID7M (spec 4.3, A5): 7M delayed one tick ----
        // Guarded on the previous edge having been enabled too (the
        // register is cleared by the hold while the input shadow is
        // unconstrained at the first enabled edge).
        if (f_run_d)
            assert(vid7m == f_m7_d);
    end else if (f_past_valid && !f_run_d) begin
        // ---- master-timing hold (spec 4.4, A6) ----
        assert(phi0 == 1'b0 && phi1 == 1'b1);
        assert(q3 == 1'b0);
        assert(pras_n && pcas_n && ldps_n);
        assert(vid7m == 1'b0);
        assert(tick_q == 4'd0);
    end
end

`endif
