    // Included inside ricoh_2c02 under FORMAL.
    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (!f_valid) assume(!rst_n);
        if (f_valid) begin
            // Raster counters stay inside the frame.
            assert(dot <= 9'd340);
            assert(scanline <= PRE_LINE);
            // /NMI is exactly the vblank flag gated by PPUCTRL.7.
            assert(nmi_n == !(vbl && ctrl[7]));
            // Bus writes come only from a pending CPU $2007 write.
            if (vram_we) assert(acc_left == 2'd1 && acc_write && !vram_rd);
            if (vram_rd || vram_we) assert(vram_addr == acc_addr || fetch_line);
            assert(acc_left <= 2'd2);
            if (rst_n && $past(rst_n)) begin
                // Dot counter advances exactly on dot_ce.
                if (!$past(dot_ce)) assert(dot == $past(dot) && scanline == $past(scanline));
                // Pixels are produced only for visible dots.
                // (the raster has advanced one dot past the emitted pixel).
                if (pixel_valid) assert(scanline < 9'd240 && dot >= 9'd2 && dot <= 9'd257);
                // w toggles on each $2005/$2006 write and clears on $2002 reads.
                if ($past(cpu_ce && cpu_cs && cpu_we && (cpu_addr == 3'd5 || cpu_addr == 3'd6)))
                    assert(w == !$past(w));
                if ($past(cpu_ce && cpu_cs && !cpu_we && cpu_addr == 3'd2)) assert(!w && !vbl);
                // Second $2006 write copies t to v.
                if ($past(cpu_ce && cpu_cs && cpu_we && cpu_addr == 3'd6 && w))
                    assert(v == {$past(t[14:8]), $past(cpu_wdata)});
            end
        end
        cover(f_valid && rst_n && vram_we);
        cover(f_valid && rst_n && acc_left == 2'd1 && !acc_write);
        cover(f_valid && rst_n && $past(cpu_ce && cpu_cs && cpu_we && cpu_addr == 3'd6) && w == 1'b0);
        cover(f_valid && rst_n && pixel_valid);
    end
