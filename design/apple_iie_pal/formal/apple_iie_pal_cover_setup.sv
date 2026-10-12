// Apple IIe PAL cover properties (non-vacuity).
// Included under `ifdef FORMAL (active only when FORMAL_COVER is also
// defined, per the .sby cover task).

`ifdef FORMAL_COVER

always_ff @(posedge clk14) begin
    if (rst_n && entmg_n) begin
        // Phase corners (spec 4.1)
        cover(tick_q == 4'd0);                    // phi0 rising
        cover(tick_q == 4'd6);                    // last CPU tick
        cover(tick_q == 4'd7);                    // phi1 start
        cover(tick_q == 4'd13);                   // last video tick
        // Q3 corners: both falls and both rises per cycle (spec 4.1)
        cover(tick_q == 4'd4 && !q3);
        cover(tick_q == 4'd11 && !q3);
        cover(tick_q == 4'd7 && q3);
        // PRAS' fall coincident with Q3 fall (spec 4.2)
        cover(tick_q == 4'd4 && !pras_n && !q3);
        // PCAS' fall on a RAM cycle (spec 4.2)
        cover(tick_q == 4'd6 && !pcas_n && !ramen_n);
        // Gated cycle: ROM/no-RAM cycle holds CAS high through the window
        cover(tick_q == 4'd9 && ramen_n && pcas_n);
        cover(tick_q == 4'd9 && !ramen_n && !pcas_n);
        // LDPS' cadences (spec 4.3, A4)
        cover(tick_q == 4'd13 && !ldps_n);                       // always pulse
        cover(tick_q == 4'd6 && !ldps_n && !s80vid_n);           // 80-col only
        cover(tick_q == 4'd6 && ldps_n && s80vid_n);             // 40-col off
        // VID7M tracks 7M both ways (spec 4.3, A5)
        cover(vid7m && !m7);
        cover(!vid7m && m7);
        // 80-column switch toggling across a pulse tick
        cover(tick_q == 4'd6 && s80vid_n);
    end
end

// Master-timing hold entered (spec 4.4, A6) — outside the enable guard,
// since the state being covered is the hold itself.
always_ff @(posedge clk14) begin
    if (f_past_valid) begin
        cover(!entmg_n && phi0 == 1'b0 && pras_n && ldps_n);
    end
end

`endif
