// Apple IIe MMU cover properties (non-vacuity for the property classes).
// Included inside apple_iie_mmu.sv under `ifdef FORMAL when FORMAL_COVER is
// defined. Each cover corresponds to one class in plans/formal_plan.md.

`ifdef FORMAL_COVER

logic c_past_valid;
initial c_past_valid = 1'b0;

integer c_step;
initial c_step = 0;

always_ff @(posedge clk) begin
    c_past_valid <= 1'b1;
    if (rst_n && c_past_valid) c_step <= c_step + 1;

    if (rst_n && c_past_valid) begin
        // Class 1/2: main RAM cycle, auxiliary RAM cycle, suppressed cycle.
        if (main_cycle) cover(1);
        if (aux_cycle) cover(1);
        if (ram_suppressed && in_df) cover(1);

        // Class 3: ROM reads in both ROMEN windows; protected LC write.
        if (rom_d_read) cover(1);
        if (rom_ef_read) cover(1);
        if (in_df && !rw && !wren) cover(1);

        // Class 3: video-page override and plain RAMRD/RAMWRT aux selection.
        if (textpg1 && store80 && sel_aux) cover(1);
        if (hirespg1 && hires && store80 && sel_aux) cover(1);
        if (zp_stack && altzp && sel_aux) cover(1);
        if (rw && ramrd && sel_aux && !store80) cover(1);
        if (!rw && ramwrt && sel_aux && !store80) cover(1);

        // Class 5: the language-card dances.
        if (access_c08x && a[0] && rw) cover(1);            // odd read
        if (access_c08x && !a[0]) cover(1);                 // even access
        if (wren && access_c08x) cover(1);                  // write-enabled LC access
        if (rdram && access_c08x) cover(1);                 // read-RAM selection

        // Class 6: row and column phases, bank-1 remap on RA4.
        if (pras_n && in_d && !bank2) cover(1);
        if (!pras_n && in_d && !bank2) cover(1);
        if (!pras_n && in_d && bank2) cover(1);

        // Class 7: expansion window lifecycle.
        if (access_intc3 && !c8win) cover(1);
        if (intc8acc) cover(1);
        if (c8win && a == 16'hCFFF) cover(1);

        // Class 4: MD7 flag readback and keyboard enable.
        if (md7_oe) cover(1);
        if (kbd_n == 1'b0) cover(1);
        if (cxxxout) cover(1);

        // Class 8: the MPON reset sequence.
        if (mpon) cover(1);
    end
end

`endif
