`timescale 1ns/1ps
// Behavioural testbench arithmetic mixes int and vector widths freely.
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off BLKSEQ */
// Directed 2C02/2C07 checks: frame/dot timing, odd-frame skip, vblank/NMI,
// register semantics ($2002/$2005/$2006/$2007 buffer, palette mirroring),
// and a full rendered frame (scrolled background + sprites) compared
// pixel-for-pixel against an independent behavioural reference renderer
// written from the NESdev rendering description, plus sprite-zero hit and
// sprite overflow.
module tb_top;
`ifdef PAL_REGION
    localparam bit REGION = 1'b1;
    localparam int LINES = 312, DIV = 5;
`else
    localparam bit REGION = 1'b0;
    localparam int LINES = 262, DIV = 4;
`endif
    localparam int PRE = LINES - 1;
    logic clk = 0, rst_n = 0, dot_ce = 0, cpu_ce = 0, cpu_cs = 0, cpu_we = 0;
    logic [2:0] cpu_addr = 0;
    logic [7:0] cpu_wdata = 0, cpu_rdata;
    logic nmi_n, vram_rd, vram_we, pixel_valid, frame_odd;
    logic [13:0] vram_addr;
    logic [7:0] vram_wdata, vram_rdata;
    logic [5:0] pixel;
    logic [2:0] emphasis;
    logic [8:0] scanline, dot;
    logic [7:0] vram [0:16383];
    logic [5:0] frame [0:239][0:255];
    logic [5:0] pal_model [0:31];
    int unsigned checks = 0, div = 0;

    ricoh_2c02 #(.REGION(REGION)) dut (.*);
    assign vram_rdata = vram[vram_addr];

    always #1 clk = !clk;
    always_ff @(posedge clk) begin
        div <= (div == DIV - 1) ? 0 : div + 1;
        if (dot_ce && vram_we) vram[vram_addr] <= vram_wdata;
        if (dot_ce && pixel_valid) frame[scanline][dot - 2] <= pixel;
    end
    // dot_ce sampled by the PPU on the edge where div wraps.
    assign dot_ce = div == DIV - 1;

    task automatic check(input bit ok, input string what);
        if (!ok) $fatal(1, "2C02 FAIL: %s (line %0d dot %0d)", what, scanline, dot);
        checks++;
    endtask
    task automatic clocks(input int n); repeat (n) @(posedge clk); #0.1; endtask
    task automatic dots(input int n); repeat (n) begin @(posedge clk iff dot_ce); #0.1; end endtask
    task automatic wait_pos(input int l, input int d);
        while (!(scanline == 9'(l) && dot == 9'(d))) begin @(posedge clk); #0.1; end
    endtask
    task automatic reg_wr(input logic [2:0] a, input logic [7:0] d);
        cpu_cs = 1; cpu_we = 1; cpu_addr = a; cpu_wdata = d; cpu_ce = 1;
        @(posedge clk); #0.1; cpu_ce = 0; cpu_cs = 0; cpu_we = 0;
        clocks(11);                     // one CPU cycle at master/12
    endtask
    task automatic reg_rd(input logic [2:0] a, output logic [7:0] d);
        cpu_cs = 1; cpu_we = 0; cpu_addr = a; cpu_ce = 1;
        @(posedge clk); #0.1; cpu_ce = 0; cpu_cs = 0; d = cpu_rdata;
        clocks(11);
    endtask
    task automatic vram_write(input logic [13:0] a, input logic [7:0] d);
        reg_wr(6, {2'b0, a[13:8]}); reg_wr(6, a[7:0]); reg_wr(7, d);
    endtask

    // ---- Independent reference renderer (NESdev PPU rendering) ----
    function automatic logic [4:0] mirror(input logic [4:0] a);
        mirror = (a[1:0] == 0) ? {1'b0, a[3:0]} : a;
    endfunction
    function automatic logic [7:0] nt_read(input int addr);
        nt_read = vram[14'(addr)];
    endfunction
    function automatic logic [5:0] ref_pixel(input int x, input int y, input int sx, input int sy,
                                             input logic [7:0] ctrl, input logic [7:0] mask,
                                             input logic [7:0] oam [0:255], output bit s0);
        int wx, wy, nt, tile_x, tile_y, base, tile, row, attr, sh, bg, sp, spal, sbehind, i;
        logic [7:0] lo, hi, at;
        s0 = 0;
        wx = x + sx + ((ctrl & 1) ? 256 : 0);
        wy = y + sy + ((ctrl & 2) ? 240 : 0);
        nt = ((wx / 256) % 2) + 2 * ((wy / 240) % 2);
        wx = wx % 256; wy = wy % 240;
        tile_x = wx / 8; tile_y = wy / 8;
        base = 'h2000 + nt * 'h400;
        tile = nt_read(base + tile_y * 32 + tile_x);
        row = ((ctrl >> 4) & 1) * 'h1000 + tile * 16 + (wy % 8);
        lo = vram[14'(row)]; hi = vram[14'(row + 8)];
        bg = {hi[7 - wx % 8], lo[7 - wx % 8]};
        at = nt_read(base + 'h3c0 + (tile_y / 4) * 8 + tile_x / 4);
        sh = ((tile_y % 4) / 2) * 4 + ((tile_x % 4) / 2) * 2;
        attr = (at >> sh) & 3;
        if (!mask[3] || (x < 8 && !mask[1])) bg = 0;
        sp = 0; spal = 0; sbehind = 0;
        if (mask[4] && !(x < 8 && !mask[2])) begin
            int count = 0;
            for (i = 0; i < 64; i++) begin
                int top = oam[i*4] + 1, dy = y - top, dx = x - oam[i*4+3];
                if (y >= 1 && dy >= 0 && dy < 8) begin
                    count++;
                    if (count <= 8 && dx >= 0 && dx < 8 && sp == 0) begin
                        int r = oam[i*4+2][7] ? 7 - dy : dy;
                        int c = oam[i*4+2][6] ? dx : 7 - dx;
                        int prow = ((ctrl >> 3) & 1) * 'h1000 + oam[i*4+1] * 16 + r;
                        int p = {vram[14'(prow + 8)][c], vram[14'(prow)][c]};
                        if (p != 0) begin
                            sp = p; spal = oam[i*4+2] & 3; sbehind = oam[i*4+2][5];
                            if (i == 0 && bg != 0 && x != 255) s0 = 1;
                        end
                    end
                end
            end
        end
        if (bg == 0 && sp == 0) ref_pixel = pal_model[0];
        else if (bg == 0) ref_pixel = pal_model[mirror(5'(16 + spal * 4 + sp))];
        else if (sp == 0 || sbehind) ref_pixel = pal_model[mirror(5'(attr * 4 + bg))];
        else ref_pixel = pal_model[mirror(5'(16 + spal * 4 + sp))];
    endfunction

    initial begin
        logic [7:0] d, ctrl_v, mask_v;
        logic [7:0] oam [0:255];
        int frame_dots, n, first_hit, sx, sy, mismatches;
        bit s0, any_s0;
        foreach (vram[i]) vram[i] = 8'h00;
        foreach (oam[i]) oam[i] = 8'hf8;     // Y=F8: off screen
        clocks(4); rst_n = 1;

        // ---- Frame timing, rendering off ----
        wait_pos(0, 0);
        n = 0; do begin dots(1); n++; end while (!(scanline == 0 && dot == 0));
        check(n == 341 * LINES, $sformatf("frame length off %0d", n));

        // ---- Vblank / NMI ----
        reg_wr(0, 8'h80);
        wait_pos(241, 1);
        check(nmi_n && !dut.vbl, "vblank not yet set before line 241 dot 1");
        dots(1);
        check(dut.vbl && !nmi_n, "vblank+NMI at line 241 dot 1");
        reg_rd(2, d);
        check(d[7] && nmi_n && !dut.vbl, "$2002 read returns and clears vblank");
        wait_pos(241, 1); clocks(1);
        reg_rd(2, d);                     // read on the setting dot suppresses
        check(!d[7], "read on vblank dot returns 0");
        dots(3); check(!dut.vbl && nmi_n, "vblank suppressed this frame");
        reg_wr(0, 8'h00);
        wait_pos(PRE, 1); dots(1);
        check(!dut.vbl, "pre-render clears vblank");

        // ---- VRAM / buffer / palette ----
        vram_write(14'h2123, 8'h5a);
        check(vram[14'h2123] == 8'h5a, "$2007 write reaches VRAM");
        reg_wr(6, 8'h21); reg_wr(6, 8'h23);
        reg_rd(7, d);                      // stale buffer
        reg_rd(7, d);
        check(d == 8'h5a, "$2007 read buffer delay");
        vram_write(14'h3f10, 8'h21);
        reg_wr(6, 8'h3f); reg_wr(6, 8'h00); reg_rd(7, d);
        check(d[5:0] == 6'h21, "$3F10 mirrors $3F00");
        reg_wr(5, 8'h12); reg_rd(2, d); reg_wr(5, 8'h34); reg_wr(5, 8'h56);
        check(dut.t[4:0] == 5'h06 && dut.t[9:5] == 5'h0a && dut.t[14:12] == 3'h6 && dut.fine_x == 3'h4,
              "$2002 read resets the w toggle");
        reg_wr(0, 8'h00); reg_wr(6, 8'h00); reg_wr(6, 8'h00);
        reg_wr(0, 8'h04);
        reg_wr(7, 8'h00); reg_wr(7, 8'h00);
        check(dut.v == 15'd64, "increment 32 mode");
        reg_wr(0, 8'h00);

        // ---- Scene: CHR, two nametables, attributes, palette, sprites ----
        for (int t = 0; t < 256; t++)
            for (int r = 0; r < 8; r++) begin
                vram[14'(t*16 + r)] = 8'(t * 7 + r * 13);
                vram[14'(t*16 + r + 8)] = 8'(t * 3 ^ r * 29);
                vram[14'('h1000 + t*16 + r)] = (r == 3) ? 8'h00 : 8'(t | 8'h81);
                vram[14'('h1000 + t*16 + r + 8)] = 8'(t ^ (r << 4));
            end
        for (int i = 0; i < 'h800; i++) vram[14'('h2000 + i)] = 8'((i * 5 + i / 32) & 255);
        for (int i = 0; i < 64; i++) begin
            vram[14'('h23c0 + i)] = 8'(i * 37); vram[14'('h27c0 + i)] = 8'(i * 11 + 3);
        end
        // Vertical mirroring board: $2800 = $2000, $2C00 = $2400.
        for (int i = 0; i < 'h800; i++) vram[14'('h2800 + i)] = vram[14'('h2000 + i)];
        for (int i = 0; i < 32; i++) pal_model[i] = 6'((i * 9 + 1) & 63);
        for (int i = 0; i < 32; i++) if (i[1:0] == 0 && i >= 16) pal_model[i] = pal_model[i - 16];
        reg_wr(6, 8'h3f); reg_wr(6, 8'h00);
        for (int i = 0; i < 32; i++) reg_wr(7, {2'b0, pal_model[(i[1:0] == 0 && i >= 16) ? i - 16 : i]});
        // OAM: sprite 0 opaque over the background; nine sprites share line 100.
        oam[0] = 8'd29; oam[1] = 8'h12; oam[2] = 8'h01; oam[3] = 8'd40;
        oam[4] = 8'd60; oam[5] = 8'h33; oam[6] = 8'h62; oam[7] = 8'd4;     // behind + hflip
        oam[8] = 8'd61; oam[9] = 8'h44; oam[10] = 8'h83; oam[11] = 8'd250; // vflip
        for (int s = 3; s < 12; s++) begin
            oam[s*4] = 8'd95; oam[s*4+1] = 8'(s); oam[s*4+2] = 8'(s & 3); oam[s*4+3] = 8'(s * 20);
        end
        reg_wr(3, 8'h00);
        for (int i = 0; i < 256; i++) reg_wr(4, oam[i]);
        for (int i = 0; i < 256; i++) if (i % 4 == 2) oam[i] = oam[i] & 8'he3;

        // ---- Render: scroll x=37, y=21, BG table 0, sprite table 1, nametable 1 ----
        sx = 37; sy = 21; ctrl_v = 8'h09; mask_v = 8'h1e;
        wait_pos(241, 5);
        reg_wr(0, ctrl_v);
        reg_rd(2, d);
        reg_wr(5, 8'(sx)); reg_wr(5, 8'(sy));
        reg_wr(1, mask_v);
        wait_pos(0, 0);
        first_hit = -1;
        while (!(scanline == 240 && dot == 0)) begin
            @(posedge clk); #0.1;
            if (dut.sprite0_hit && first_hit < 0) first_hit = scanline * 341 + dot;
        end
        mismatches = 0; any_s0 = 0;
        for (int y = 0; y < 240; y++)
            for (int x = 0; x < 256; x++) begin
                logic [5:0 ] want = ref_pixel(x, y, sx, sy, ctrl_v, mask_v, oam, s0);
                if (s0 && !any_s0) begin
                    any_s0 = 1;
                    // The flag is set while the hit pixel's dot is processed.
                    check(first_hit == y * 341 + x + 2, $sformatf("sprite-0 hit at x=%0d y=%0d, flag at %0d",
                          x, y, first_hit));
                end
                if (frame[y][x] != want) begin
                    if (mismatches < 8) $display("pixel (%0d,%0d) rtl=%02x ref=%02x", x, y, frame[y][x], want);
                    mismatches++;
                end
            end
        if (mismatches) for (int y = 0; y < 3; y++) begin
            string a = "", b = "";
            bit tmp;
            for (int x = 0; x < 40; x++) begin
                a = {a, $sformatf("%02x ", frame[y][x])}; b = {b, $sformatf("%02x ", ref_pixel(x, y, sx, sy, ctrl_v, mask_v, oam, tmp))};
            end
            $display("rtl %0d: %s", y, a); $display("ref %0d: %s", y, b);
        end
        check(mismatches == 0, $sformatf("%0d pixel mismatches against reference", mismatches));
        check(any_s0 && first_hit >= 0, "sprite-0 hit occurs");
        check(dut.sprite_ovf, "nine sprites on a line set overflow");

        // ---- Odd-frame skip with rendering enabled ----
        if (!REGION) begin
            int a, b;
            wait_pos(0, 0); n = 0; do begin dots(1); n++; end while (!(scanline == 0 && dot == 0)); a = n;
            n = 0; do begin dots(1); n++; end while (!(scanline == 0 && dot == 0)); b = n;
            check((a == 89342 && b == 89341) || (a == 89341 && b == 89342), $sformatf("odd frame skip %0d/%0d", a, b));
        end else begin
            wait_pos(0, 0); n = 0; do begin dots(1); n++; end while (!(scanline == 0 && dot == 0));
            check(n == 341 * 312, "PAL frames never skip");
        end

        $display("RICOH 2C02 TB PASS: region=%0d checks=%0d", REGION, checks);
        $finish;
    end
endmodule
