// Ricoh 5C77 (S-PPU1): SNES picture processor, first half. Owns the VRAM
// port, OAM, the background/sprite/Mode 7 registers and pixel generation.
// Each displayed line is rendered into a line buffer while the line is
// scanned; S-PPU2 composes the previous line from the other buffer bank.
// See spec/spec.md for the rendering model and the assumption ledger.
module ricoh_5c77 (
    input  logic clk,
    input  logic rst_n,
    // B bus.
    input  logic [7:0] b_addr,
    input  logic b_rd, b_wr, bus_ce,
    input  logic [7:0] b_data_i,
    output logic [7:0] rdata,
    output logic hit,
    // VRAM, 32K x 16. Render port and CPU port, both with registered read.
    output logic [14:0] vram_raddr,
    input  logic [15:0] vram_rdata,
    output logic [14:0] vram_caddr,
    output logic vram_cwe_lo, vram_cwe_hi,
    output logic [7:0] vram_cwdata,
    input  logic [15:0] vram_cdata,
    // Timing from S-PPU2.
    input  logic line_start,          // first clock of a line
    input  logic [8:0] line,
    input  logic vblank,
    input  logic field,
    // Layer read port for S-PPU2 (previous line).
    input  logic [9:0] px_x,          // 0-255, or 0-511 in high resolution
    input  logic px_bank,
    output logic [47:0] bg_px,           // {priority, palette[2:0], colour[7:0]}
    output logic [8:0] obj_px,        // {priority[1:0], palette[2:0], colour[3:0]}
    output logic [7:0] mode_o,        // BGMODE
    output logic hires_o
);
    // Register bits the hardware ignores and wide arithmetic temporaries
    // whose upper bits are deliberately dropped.
    /* verilator lint_off UNUSEDSIGNAL */
    // ---------------- Registers ----------------
    logic [7:0] obsel, bgmode, mosaic, vmain, m7sel, setini, inidisp;
    logic [7:0] bgsc [4];
    logic [3:0] bgnba [4];
    logic [9:0] hofs [4], vofs [4];
    logic [7:0] bgofs_latch, bgofs_latch2, m7_latch;
    logic vfetch_next;
    logic [14:0] vhold;
    wire [8:0] vblank_first = setini[2] ? 9'd240 : 9'd225;
    logic [15:0] vaddr;
    logic [15:0] vlatch;
    logic [15:0] m7a, m7b, m7c, m7d;
    logic [12:0] m7x, m7y, m7hofs, m7vofs;
    // Copies taken at the start of each line for the renderer, so HDMA writes
    // for the next line (horizontal blank) never reach the line being drawn.
    logic [9:0] lhofs [4], lvofs [4];
    logic [15:0] lm7a, lm7b, lm7c, lm7d;
    logic [12:0] lm7x, lm7y, lm7hofs, lm7vofs;
    logic [7:0] lm7sel;
    logic [8:0] oamadd;
    logic oam_prio;
    logic [9:0] oam_addr;
    logic [7:0] oam_latch;
    logic [7:0] oam [544];
    logic range_over, time_over;
    logic [7:0] mdr;
    logic [23:0] m7_product;

    // VRAM address translation and increment.
    function automatic logic [14:0] vremap(input logic [15:0] ad, input logic [1:0] mode);
        case (mode)
            2'd1: vremap = {ad[14:8], ad[4:0], ad[7:5]};
            2'd2: vremap = {ad[14:9], ad[5:0], ad[8:6]};
            2'd3: vremap = {ad[14:10], ad[6:0], ad[9:7]};
            default: vremap = ad[14:0];
        endcase
    endfunction
    logic [15:0] vinc;
    always_comb begin
        case (vmain[1:0])
            2'd0: vinc = 16'd1;
            2'd1: vinc = 16'd32;
            default: vinc = 16'd128;
        endcase
    end
    wire vram_ok = vblank || inidisp[7];

    // CPU VRAM port.
    always_comb begin
        vram_caddr = vfetch_next ? vhold : vremap(vaddr, vmain[3:2]);
        vram_cwe_lo = b_wr && bus_ce && b_addr == 8'h18 && vram_ok;
        vram_cwe_hi = b_wr && bus_ce && b_addr == 8'h19 && vram_ok;
        vram_cwdata = b_data_i;
    end
    logic vfetch;                // reload the read latch next clock

    // Register reads.
    always_comb begin
        hit = 1'b1;
        rdata = mdr;
        m7_product = $signed(m7a) * $signed(m7b[15:8]);
        case (b_addr)
            8'h34: rdata = m7_product[7:0];
            8'h35: rdata = m7_product[15:8];
            8'h36: rdata = m7_product[23:16];
            8'h38: rdata = oam[oam_addr[9] ? {5'b10000, oam_addr[4:0]} : oam_addr];
            8'h39: rdata = vlatch[7:0];
            8'h3a: rdata = vlatch[15:8];
            8'h3e: rdata = {time_over, range_over, 1'b0, mdr[4], 4'h1};
            8'h04, 8'h05, 8'h06, 8'h08, 8'h09, 8'h0a, 8'h14, 8'h15, 8'h16,
            8'h18, 8'h19, 8'h1a, 8'h24, 8'h25, 8'h26, 8'h28, 8'h29, 8'h2a: rdata = mdr;
            default: hit = b_addr[7:6] == 2'b00 && b_addr[5:0] < 6'h34 ? 1'b1 : 1'b0;
        endcase
        if (b_addr >= 8'h40) hit = 1'b0;
        if (b_addr == 8'h37 || b_addr == 8'h3b || b_addr == 8'h3c || b_addr == 8'h3d ||
            b_addr == 8'h3f) hit = 1'b0;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            obsel <= 8'h00; bgmode <= 8'h00; mosaic <= 8'h00; vmain <= 8'h80; m7sel <= 8'h00;
            setini <= 8'h00; inidisp <= 8'h80;
            for (int i = 0; i < 4; i++) begin
                bgsc[i] <= 8'h00; bgnba[i] <= 4'h0; hofs[i] <= 10'h0; vofs[i] <= 10'h0;
            end
            bgofs_latch <= 8'h00; bgofs_latch2 <= 8'h00; m7_latch <= 8'h00; vfetch_next <= 1'b0; vhold <= 15'h0;
            vaddr <= 16'h0000; vlatch <= 16'h0000; vfetch <= 1'b0;
            m7a <= 16'h0000; m7b <= 16'h0000; m7c <= 16'h0000; m7d <= 16'h0000;
            m7x <= 13'h0; m7y <= 13'h0; m7hofs <= 13'h0; m7vofs <= 13'h0;
            oamadd <= 9'h0; oam_prio <= 1'b0; oam_addr <= 10'h0; oam_latch <= 8'h00;
            mdr <= 8'h00;
        end else begin
            vfetch <= 1'b0;
            if (vfetch) vlatch <= vram_cdata;
            // OAM address reload at the start of vertical blank.
            if (line_start && vblank && line == vblank_first && !inidisp[7])
                oam_addr <= {oamadd, 1'b0};
            if (bus_ce && b_wr) begin
                case (b_addr)
                    8'h00: inidisp <= b_data_i;
                    8'h01: obsel <= b_data_i;
                    8'h02: begin oamadd[7:0] <= b_data_i; oam_addr <= {oamadd[8], b_data_i, 1'b0}; end
                    8'h03: begin
                        oamadd[8] <= b_data_i[0];
                        oam_prio <= b_data_i[7];
                        oam_addr <= {b_data_i[0], oamadd[7:0], 1'b0};
                    end
                    8'h04: begin
                        if (oam_addr[9]) oam[{5'b10000, oam_addr[4:0]}] <= b_data_i;
                        else if (!oam_addr[0]) oam_latch <= b_data_i;
                        else begin
                            oam[{oam_addr[9:1], 1'b0}] <= oam_latch;
                            oam[oam_addr] <= b_data_i;
                        end
                        oam_addr <= oam_addr + 10'd1;
                    end
                    8'h05: bgmode <= b_data_i;
                    8'h06: mosaic <= b_data_i;
                    8'h07, 8'h08, 8'h09, 8'h0a: bgsc[b_addr[1:0] - 2'd3] <= b_data_i;
                    8'h0b: begin bgnba[0] <= b_data_i[3:0]; bgnba[1] <= b_data_i[7:4]; end
                    8'h0c: begin bgnba[2] <= b_data_i[3:0]; bgnba[3] <= b_data_i[7:4]; end
                    8'h0d, 8'h0f, 8'h11, 8'h13: begin
                        hofs[2'((b_addr[3:0] - 4'hd) >> 1)] <= {b_data_i[1:0], bgofs_latch[7:3],
                                                             bgofs_latch2[2:0]};
                        bgofs_latch <= b_data_i;
                        bgofs_latch2 <= b_data_i;
                        if (b_addr == 8'h0d) begin
                            m7hofs <= {b_data_i[4:0], m7_latch};
                            m7_latch <= b_data_i;
                        end
                    end
                    8'h0e, 8'h10, 8'h12, 8'h14: begin
                        vofs[2'((b_addr[3:0] - 4'he) >> 1)] <= {b_data_i[1:0], bgofs_latch};
                        bgofs_latch <= b_data_i;
                        if (b_addr == 8'h0e) begin
                            m7vofs <= {b_data_i[4:0], m7_latch};
                            m7_latch <= b_data_i;
                        end
                    end
                    8'h15: vmain <= b_data_i;
                    8'h16: begin
                        vaddr[7:0] <= b_data_i;
                        vhold <= vremap({vaddr[15:8], b_data_i}, vmain[3:2]);
                        vfetch_next <= 1'b1;
                    end
                    8'h17: begin
                        vaddr[15:8] <= b_data_i;
                        vhold <= vremap({b_data_i, vaddr[7:0]}, vmain[3:2]);
                        vfetch_next <= 1'b1;
                    end
                    8'h18: if (!vmain[7]) vaddr <= vaddr + vinc;
                    8'h19: if (vmain[7]) vaddr <= vaddr + vinc;
                    8'h1a: m7sel <= b_data_i;
                    8'h1b: begin m7a <= {b_data_i, m7_latch}; m7_latch <= b_data_i; end
                    8'h1c: begin m7b <= {b_data_i, m7_latch}; m7_latch <= b_data_i; end
                    8'h1d: begin m7c <= {b_data_i, m7_latch}; m7_latch <= b_data_i; end
                    8'h1e: begin m7d <= {b_data_i, m7_latch}; m7_latch <= b_data_i; end
                    8'h1f: begin m7x <= {b_data_i[4:0], m7_latch}; m7_latch <= b_data_i; end
                    8'h20: begin m7y <= {b_data_i[4:0], m7_latch}; m7_latch <= b_data_i; end
                    8'h33: setini <= b_data_i;
                    default: ;
                endcase
            end
            if (bus_ce && b_rd && hit) begin
                mdr <= rdata;
                case (b_addr)
                    8'h38: oam_addr <= oam_addr + 10'd1;
                    8'h39: if (!vmain[7]) begin
                        vhold <= vremap(vaddr, vmain[3:2]);
                        vfetch_next <= 1'b1;
                        vaddr <= vaddr + vinc;
                    end
                    8'h3a: if (vmain[7]) begin
                        vhold <= vremap(vaddr, vmain[3:2]);
                        vfetch_next <= 1'b1;
                        vaddr <= vaddr + vinc;
                    end
                    default: ;
                endcase
            end
            // Read-latch reload: the held address is presented for one
            // clock and the registered VRAM data arrives on the next.
            if (vfetch_next && !(bus_ce && (b_wr || b_rd))) begin
                vfetch_next <= 1'b0;
                vfetch <= 1'b1;
            end
        end
    end
    assign mode_o = bgmode;
    wire [2:0] mode = bgmode[2:0];
    assign hires_o = mode == 3'd5 || mode == 3'd6;

    // ---------------- Line buffers ----------------
    logic [11:0] bgbuf [2][4][512];
    logic [8:0] objbuf [2][256];

    // ---------------- Per-line render ----------------
    // Bits per pixel of each background in the current mode (0 = off).
    function automatic logic [3:0] bg_bpp(input logic [2:0] m, input logic [1:0] n);
        case (m)
            3'd0: bg_bpp = 4'd2;
            3'd1: bg_bpp = n == 2'd3 ? 4'd0 : (n == 2'd2 ? 4'd2 : 4'd4);
            3'd2: bg_bpp = n < 2'd2 ? 4'd4 : 4'd0;
            3'd3: bg_bpp = n == 2'd0 ? 4'd8 : (n == 2'd1 ? 4'd4 : 4'd0);
            3'd4: bg_bpp = n == 2'd0 ? 4'd8 : (n == 2'd1 ? 4'd2 : 4'd0);
            3'd5: bg_bpp = n == 2'd0 ? 4'd4 : (n == 2'd1 ? 4'd2 : 4'd0);
            3'd6: bg_bpp = n == 2'd0 ? 4'd4 : 4'd0;
            default: bg_bpp = 4'd0;
        endcase
    endfunction
    wire opt_mode = mode == 3'd2 || mode == 3'd4 || mode == 3'd6;

    typedef enum logic [4:0] {
        R_IDLE, R_CLEAR, R_OBJ_EVAL, R_OBJ_NEXT, R_OBJ_C0, R_OBJ_C1, R_OBJ_C2, R_OBJ_PIX,
        R_BG_START, R_BG_OPT0, R_BG_OPT1, R_BG_OPT2, R_BG_MAP, R_BG_MAPW, R_BG_CHR, R_BG_PIX,
        R_M7_MAP, R_M7_CHR, R_M7_PIX, R_DONE
    } rstate_e;
    rstate_e rs;
    logic bank;                         // bank being rendered
    logic [8:0] rline;                  // line being rendered
    logic [9:0] clr;
    // Mosaic line.
    logic [8:0] mos_line;
    logic [4:0] mos_cnt;

    // Sprite evaluation.
    logic [6:0] obj_i;
    logic [7:0] obj_n;                  // sprites evaluated
    logic [6:0] obj_list [32];
    logic [5:0] obj_count;              // sprites in range
    logic [5:0] obj_k;                  // list position being fetched
    logic [3:0] sliver;                 // sliver within the current sprite
    logic [5:0] slivers;                // slivers fetched this line
    logic [15:0] obj_plane01;

    // Sprite size helpers: OBSEL size field -> small/large widths and heights.
    function automatic logic [6:0] obj_w(input logic [2:0] sz, input logic lg);
        case (sz)
            3'd0: obj_w = lg ? 7'd16 : 7'd8;
            3'd1: obj_w = lg ? 7'd32 : 7'd8;
            3'd2: obj_w = lg ? 7'd64 : 7'd8;
            3'd3: obj_w = lg ? 7'd32 : 7'd16;
            3'd4: obj_w = lg ? 7'd64 : 7'd16;
            3'd5: obj_w = lg ? 7'd64 : 7'd32;
            3'd6: obj_w = lg ? 7'd32 : 7'd16;
            default: obj_w = lg ? 7'd32 : 7'd16;
        endcase
    endfunction
    function automatic logic [6:0] obj_h(input logic [2:0] sz, input logic lg);
        case (sz)
            3'd6: obj_h = lg ? 7'd64 : 7'd32;
            3'd7: obj_h = lg ? 7'd32 : 7'd32;
            default: obj_h = obj_w(sz, lg);
        endcase
    endfunction

    // OAM entry fields for sprite n.
    function automatic logic [8:0] oam_x(input logic [6:0] n);
        oam_x = {oam[{3'b100, 2'b00, n[6:2]}][{n[1:0], 1'b0}], oam[{1'b0, n, 2'b00}]};
    endfunction
    function automatic logic oam_large(input logic [6:0] n);
        oam_large = oam[{5'b10000, n[6:2]}][{n[1:0], 1'b1}];
    endfunction

    // Current sprite being fetched.
    wire [6:0] cs = obj_list[obj_k[4:0]];
    wire [8:0] cs_x = oam_x(cs);
    wire [7:0] cs_y = oam[{1'b0, cs, 2'b01}];
    wire [7:0] cs_tile = oam[{1'b0, cs, 2'b10}];
    wire [7:0] cs_attr = oam[{1'b0, cs, 2'b11}];
    wire cs_large = oam_large(cs);
    wire [6:0] cs_w = obj_w(obsel[7:5], cs_large);
    wire [6:0] cs_h = obj_h(obsel[7:5], cs_large);
    // Sprite line (OBJ interlace uses doubled lines). Sprites are evaluated
    // on the line before they are shown, so OAM Y = 0 starts on line 1.
    wire [8:0] obj_rl = rline - 9'd1;
    wire [7:0] obj_line = obj_rl[7:0];
    // Row within a sprite: OBJ interlace shows every other row, by field.
    function automatic logic [7:0] obj_dy(input logic [7:0] d);
        obj_dy = setini[1] ? {d[6:0], field} : d;
    endfunction

    // Sliver geometry for the current sprite.
    logic [8:0] sl_x;
    logic [14:0] sl_addr;
    logic sl_visible;
    always_comb begin
        logic [6:0] colp, row, rowf;
        logic [7:0] dy;
        logic [7:0] t;
        logic [3:0] ct, rt;
        logic [14:0] base;
        colp = {sliver, 3'b000};
        dy = obj_dy(obj_line - cs_y);
        rowf = cs_attr[7] ? (cs_h - 7'd1 - dy[6:0]) : dy[6:0];
        row = rowf;
        // Hardware fetches slivers left to right; the column is mirrored
        // for horizontal flip.
        ct = cs_attr[6] ? ((cs_w[6:3] - 4'd1) - sliver) : sliver;
        rt = row[6:3];
        t = {cs_tile[7:4] + rt, cs_tile[3:0] + ct};
        base = {obsel[1:0], 13'h0000};
        if (cs_attr[0]) base = base + {obsel[4:3] + 2'd1, 12'h000};
        sl_addr = base + {3'b000, t, 4'h0} + {12'h000, row[2:0]};
        sl_x = cs_x + {2'b00, colp};
        sl_visible = sl_x < 9'd256 || sl_x >= 9'd505;  // within -7..255
    end

    // Sprite range test for OAM entry obj_i.
    wire [7:0] ev_d = obj_line - oam[{1'b0, obj_i, 2'b01}];
    wire [7:0] ev_dy = obj_dy(ev_d);
    wire [6:0] ev_h = obj_h(obsel[7:5], oam_large(obj_i));
    wire [8:0] ev_x = oam_x(obj_i);
    wire [6:0] ev_w = obj_w(obsel[7:5], oam_large(obj_i));
    // X = 256 still counts toward the per-line limits.
    wire ev_in = {1'b0, ev_dy} < {2'b00, ev_h} && !(setini[1] && ev_d[7]) &&
                 !(ev_x > 9'd256 && ({1'b0, ev_x} + {3'b000, ev_w} - 10'd1) < 10'd512);

    // Background fetch state.
    logic [1:0] bg;                    // layer being rendered
    logic [6:0] col;                   // tile column
    logic [15:0] map;                  // tilemap entry
    logic [15:0] chr [4];              // character words
    logic [1:0] chr_i;
    logic [9:0] col_hofs, col_vofs;    // offsets for this column (offset-per-tile)
    logic [15:0] opt_h;

    wire [3:0] bpp = bg_bpp(mode, bg);
    wire hires = hires_o;
    wire big = bgmode[4 + bg];
    // Line within the layer (mosaic, interlace in high resolution).
    wire [8:0] bg_line = mosaic[{1'b0, bg}] ? mos_line : rline;
    wire [9:0] eff_line = (hires && setini[0]) ? {bg_line[8:0], field} : {1'b0, bg_line};
    // Geometry of the current 8-pixel column. Wide tiles (16 pixels, or any
    // tile in high resolution) take the half selected by pixel bit 3.
    logic [9:0] tile_px, tile_py;
    logic [14:0] map_addr, chr_addr;
    logic [9:0] col_x;                 // screen x of the column's first pixel (wraps)
    wire [15:0] mapv = rs == R_BG_MAPW ? vram_rdata : map;
    always_comb begin
        logic [9:0] hs;
        logic [5:0] tx, ty;
        logic [9:0] tile;
        logic [2:0] fy;
        logic sub_x, sub_y;
        logic [14:0] scbase;
        logic wide;
        wide = big || hires;
        hs = hires ? {col_hofs[8:0], 1'b0} : col_hofs;
        tile_px = {col[6:0], 3'h0} + {hs[9:3], 3'h0};
        col_x = {col[6:0], 3'h0} - {7'h00, hs[2:0]};
        tile_py = eff_line + col_vofs;
        tx = wide ? tile_px[9:4] : tile_px[8:3];
        ty = big ? tile_py[9:4] : tile_py[8:3];
        scbase = {bgsc[bg][6:2], 10'h000};
        map_addr = scbase + {5'b00000, ty[4:0], tx[4:0]};
        if (tx[5] && bgsc[bg][0]) map_addr = map_addr + 15'h0400;
        if (ty[5]) begin
            if (bgsc[bg][1:0] == 2'd2) map_addr = map_addr + 15'h0400;
            if (bgsc[bg][1:0] == 2'd3) map_addr = map_addr + 15'h0800;
        end
        sub_x = wide ? (tile_px[3] ^ mapv[14]) : 1'b0;
        sub_y = big ? (tile_py[3] ^ mapv[15]) : 1'b0;
        tile = mapv[9:0] + {5'h00, sub_y, 3'h0, sub_x};
        fy = mapv[15] ? ~tile_py[2:0] : tile_py[2:0];
        case (bpp)
            4'd2: chr_addr = {bgnba[bg][2:0], 12'h000} + {2'b00, tile, fy};
            4'd4: chr_addr = {bgnba[bg][2:0], 12'h000} + {1'b0, tile, 1'b0, fy};
            default: chr_addr = {bgnba[bg][2:0], 12'h000} + {tile, 2'b00, fy};
        endcase
    end
    wire [6:0] last_col = hires ? 7'd64 : 7'd32;

    // Mode 7.
    logic [8:0] m7_x;
    logic signed [31:0] m7_psx, m7_psy, m7_px, m7_py;
    logic m7_out, m7_zero;
    function automatic logic signed [31:0] m7clip(input logic [12:0] n);
        m7clip = n[12] ? {{22{1'b1}}, n[9:0]} : {22'h0, n[9:0]};
    endfunction
    always_comb begin
        logic signed [31:0] a, b, c, d, hc, vc, ho, vo, yy, xx;
        logic [8:0] ln;
        a = 32'($signed(lm7a)); b = 32'($signed(lm7b));
        c = 32'($signed(lm7c)); d = 32'($signed(lm7d));
        hc = 32'($signed(lm7x)); vc = 32'($signed(lm7y));
        ho = 32'($signed(lm7hofs)); vo = 32'($signed(lm7vofs));
        ln = mosaic[0] ? mos_line : rline;
        yy = lm7sel[1] ? 32'(255 - $signed(32'(ln[7:0]))) : 32'(ln[7:0]);
        m7_psx = ((a * m7clip(13'(ho - hc))) & ~32'sd63) + ((b * m7clip(13'(vo - vc))) & ~32'sd63) +
                 ((b * yy) & ~32'sd63) + (hc <<< 8);
        m7_psy = ((c * m7clip(13'(ho - hc))) & ~32'sd63) + ((d * m7clip(13'(vo - vc))) & ~32'sd63) +
                 ((d * yy) & ~32'sd63) + (vc <<< 8);
        xx = lm7sel[0] ? 32'(255 - $signed(32'(m7_x[7:0]))) : 32'(m7_x[7:0]);
        m7_px = m7_psx + a * xx;
        m7_py = m7_psy + c * xx;
        m7_out = m7_px[31:18] != 14'h0 || m7_py[31:18] != 14'h0;
        m7_zero = m7_out && lm7sel[7:6] == 2'b11;
    end

    // Render port address.
    always_comb begin
        vram_raddr = map_addr;
        case (rs)
            R_OBJ_NEXT: vram_raddr = sl_addr;
            R_OBJ_C0: vram_raddr = sl_addr + 15'd8;
            R_BG_OPT0: vram_raddr = opt_addr(1'b0);
            R_BG_OPT1: vram_raddr = opt_addr(1'b1);
            R_BG_MAP: vram_raddr = map_addr;
            R_BG_MAPW, R_BG_CHR: vram_raddr = chr_addr + {9'h000, chr_ni, 3'b000};
            R_M7_MAP: vram_raddr = {1'b0, m7_py[17:11], m7_px[17:11]};
            R_M7_CHR: vram_raddr = {1'b0, m7_zero ? 8'h00 : vram_rdata[7:0], m7_py[10:8], m7_px[10:8]};
            default: ;
        endcase
    end
    logic [1:0] chr_ni;                 // character word being requested
    always_comb chr_ni = rs == R_BG_MAPW ? 2'd0 : chr_i + 2'd1;

    // Offset-per-tile entry address in the BG3 tilemap (row 0: H, row 1: V).
    function automatic logic [14:0] opt_addr(input logic row);
        logic [9:0] px, py;
        logic [5:0] tx, ty;
        logic [14:0] a;
        px = {col[6:0] - 7'd1, 3'b000} + {lhofs[2][9:3], 3'b000};
        py = lvofs[2] + {6'h00, row, 3'b000};
        tx = px[8:3];
        ty = py[8:3];
        a = {bgsc[2][6:2], 10'h000} + {5'b00000, ty[4:0], tx[4:0]};
        if (tx[5] && bgsc[2][0]) a = a + 15'h0400;
        if (ty[5]) begin
            if (bgsc[2][1:0] == 2'd2) a = a + 15'h0400;
            if (bgsc[2][1:0] == 2'd3) a = a + 15'h0800;
        end
        opt_addr = a;
    endfunction

    // Next enabled background after 'from' (4 = none).
    function automatic logic [2:0] next_bg(input logic [2:0] from, input logic [2:0] m);
        next_bg = 3'd4;
        for (int i = 3; i >= 0; i--)
            if (3'(i) >= from && bg_bpp(m, 2'(i)) != 4'd0) next_bg = 3'(i);
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rs <= R_IDLE;
            range_over <= 1'b0;
            time_over <= 1'b0;
            bank <= 1'b0;
            mos_cnt <= 5'd0;
            mos_line <= 9'd0;
        end else begin
            if (line_start) begin
                // Mosaic line counter.
                // Interlaced high resolution counts the size in 448-line
                // rows, so each block covers twice as many lines.
                if (line == 9'd1 || mos_cnt == 5'd0) begin
                    mos_line <= line;
                    mos_cnt <= (hires_o && setini[0]) ? {mosaic[7:4], 1'b1} : {1'b0, mosaic[7:4]};
                end else mos_cnt <= mos_cnt - 5'd1;
                if (line == 9'd0 && !inidisp[7]) begin
                    range_over <= 1'b0;
                    time_over <= 1'b0;
                end
                rline <= line;
                for (int i = 0; i < 4; i++) begin
                    lhofs[i] <= hofs[i];
                    lvofs[i] <= vofs[i];
                end
                lm7a <= m7a; lm7b <= m7b; lm7c <= m7c; lm7d <= m7d;
                lm7x <= m7x; lm7y <= m7y; lm7hofs <= m7hofs; lm7vofs <= m7vofs;
                lm7sel <= m7sel;
                bank <= line[0];
                clr <= 10'd0;
                rs <= (!vblank && line != 9'd0) ? R_CLEAR : R_IDLE;
            end else case (rs)
            R_IDLE: ;
            R_CLEAR: begin
                // Clear the line buffers (all entries transparent).
                for (int i = 0; i < 4; i++) begin
                    bgbuf[bank][i][clr[8:0]] <= 12'h000;
                    bgbuf[bank][i][{1'b1, clr[7:0]}] <= 12'h000;
                end
                objbuf[bank][clr[7:0]] <= 9'h000;
                clr <= clr + 10'd1;
                if (clr == 10'd255) begin
                    if (inidisp[7]) rs <= R_DONE;
                    else begin
                        rs <= R_OBJ_EVAL;
                        obj_i <= oam_prio ? oamadd[7:1] : 7'd0;
                        obj_n <= 8'd0;
                        obj_count <= 6'd0;
                    end
                end
            end
            // ---- sprites ----
            R_OBJ_EVAL: begin
                if (ev_in) begin
                    if (obj_count == 6'd32) range_over <= 1'b1;
                    else begin
                        obj_list[obj_count[4:0]] <= obj_i;
                        obj_count <= obj_count + 6'd1;
                    end
                end
                obj_i <= obj_i + 7'd1;
                obj_n <= obj_n + 8'd1;
                if (obj_n == 8'd127) begin
                    obj_k <= 6'd0;
                    sliver <= 4'd0;
                    slivers <= 6'd0;
                    rs <= R_OBJ_C2;     // choose first sliver
                end
            end
            R_OBJ_C2: begin
                // Select the next visible sliver (or the next sprite).
                if (obj_k == obj_count) begin
                    rs <= R_BG_START;
                end else if ({1'b0, sliver} >= {1'b0, cs_w[6:3]}) begin
                    obj_k <= obj_k + 6'd1;
                    sliver <= 4'd0;
                end else if (!sl_visible) begin
                    sliver <= sliver + 4'd1;
                end else if (slivers == 6'd34) begin
                    time_over <= 1'b1;
                    rs <= R_BG_START;
                end else begin
                    rs <= R_OBJ_NEXT;
                end
            end
            R_OBJ_NEXT: rs <= R_OBJ_C0;           // planes 0/1 requested
            R_OBJ_C0: begin                       // planes 2/3 requested
                obj_plane01 <= vram_rdata;
                rs <= R_OBJ_C1;
            end
            R_OBJ_C1: begin
                for (int i = 0; i < 8; i++) begin
                    logic [2:0] b;
                    logic [3:0] c;
                    logic [8:0] xx;
                    b = cs_attr[6] ? 3'(i) : 3'(7 - i);
                    c = {vram_rdata[4'd8 + {1'b0, b}], vram_rdata[{1'b0, b}], obj_plane01[4'd8 + {1'b0, b}], obj_plane01[{1'b0, b}]};
                    xx = sl_x + 9'(i);
                    if (c != 4'h0 && xx < 9'd256 && objbuf[bank][xx[7:0]][3:0] == 4'h0)
                        objbuf[bank][xx[7:0]] <= {cs_attr[5:4], cs_attr[3:1], c};
                end
                slivers <= slivers + 6'd1;
                sliver <= sliver + 4'd1;
                rs <= R_OBJ_C2;
            end
            // ---- backgrounds ----
            R_BG_START: begin
                logic [2:0] nb;
                nb = next_bg(3'd0, mode);
                if (mode == 3'd7) begin
                    m7_x <= 9'd0;
                    rs <= R_M7_MAP;
                end else if (nb[2]) rs <= R_DONE;
                else begin
                    bg <= nb[1:0];
                    col <= 7'd0;
                    col_hofs <= lhofs[nb[1:0]];
                    col_vofs <= lvofs[nb[1:0]];
                    rs <= R_BG_MAP;
                end
            end
            R_BG_OPT0: rs <= R_BG_OPT1;           // H entry requested
            R_BG_OPT1: begin                      // V entry requested
                opt_h <= vram_rdata;
                rs <= R_BG_OPT2;
            end
            R_BG_OPT2: begin
                logic [15:0] h, v;
                h = opt_h;
                v = vram_rdata;
                col_hofs <= lhofs[bg];
                col_vofs <= lvofs[bg];
                if (mode == 3'd4) begin
                    // One entry: bit 15 selects vertical or horizontal.
                    if (h[4'd13 + {2'b00, bg}]) begin
                        if (h[15]) col_vofs <= h[9:0];
                        else col_hofs <= {h[9:3], lhofs[bg][2:0]};
                    end
                end else begin
                    if (h[4'd13 + {2'b00, bg}]) col_hofs <= {h[9:3], lhofs[bg][2:0]};
                    if (v[4'd13 + {2'b00, bg}]) col_vofs <= v[9:0];
                end
                rs <= R_BG_MAP;
            end
            R_BG_MAP: rs <= R_BG_MAPW;            // tilemap requested
            R_BG_MAPW: begin                      // tilemap arrives, char 0 requested
                map <= vram_rdata;
                chr_i <= 2'd0;
                rs <= R_BG_CHR;
            end
            R_BG_CHR: begin
                chr[chr_i] <= vram_rdata;
                if ({1'b0, chr_i} == 3'(bpp[3:1] - 3'd1)) rs <= R_BG_PIX;
                else chr_i <= chr_i + 2'd1;
            end
            R_BG_PIX: begin
                for (int i = 0; i < 8; i++) begin
                    logic [9:0] xx;
                    logic [7:0] c;
                    logic [2:0] bit_n;
                    bit_n = map[14] ? 3'(i) : 3'(7 - i);
                    c = {chr[3][4'd8 + {1'b0, bit_n}], chr[3][{1'b0, bit_n}], chr[2][4'd8 + {1'b0, bit_n}], chr[2][{1'b0, bit_n}],
                         chr[1][4'd8 + {1'b0, bit_n}], chr[1][{1'b0, bit_n}], chr[0][4'd8 + {1'b0, bit_n}], chr[0][{1'b0, bit_n}]};
                    if (bpp == 4'd2) c[7:2] = 6'h00;
                    if (bpp == 4'd4) c[7:4] = 4'h0;
                    xx = col_x + 10'(i);
                    if (c != 8'h00 && ((hires && xx < 10'd512) || (!hires && xx < 10'd256)))
                        bgbuf[bank][bg][xx[8:0]] <= {map[13], map[12:10], c};
                end
                if (col == last_col) begin
                    logic [2:0] nb;
                    nb = next_bg({1'b0, bg} + 3'd1, mode);
                    if (nb[2]) rs <= R_DONE;
                    else begin
                        bg <= nb[1:0];
                        col <= 7'd0;
                        col_hofs <= lhofs[nb[1:0]];
                        col_vofs <= lvofs[nb[1:0]];
                        rs <= R_BG_MAP;
                    end
                end else begin
                    col <= col + 7'd1;
                    if (opt_mode && bg != 2'd2) rs <= R_BG_OPT0;
                    else rs <= R_BG_MAP;
                end
            end
            // ---- mode 7 ----
            R_M7_MAP: rs <= R_M7_CHR;             // map byte requested
            R_M7_CHR: rs <= R_M7_PIX;             // pixel byte requested
            R_M7_PIX: begin
                logic [7:0] p;
                p = vram_rdata[15:8];
                if (m7_out && lm7sel[7:6] == 2'b10) p = 8'h00;
                if (p != 8'h00) bgbuf[bank][0][{1'b0, m7_x[7:0]}] <= {1'b0, 3'b000, p};
                if (p[6:0] != 7'h00) bgbuf[bank][1][{1'b0, m7_x[7:0]}] <= {p[7], 3'b000, 1'b0, p[6:0]};
                m7_x <= m7_x + 9'd1;
                rs <= m7_x == 9'd255 ? R_DONE : R_M7_MAP;
            end
            default: ;
            endcase
        end
    end

    // ---------------- Layer read port (with horizontal mosaic) ----------------
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            logic [9:0] mx;
            logic [4:0] sz;
            sz = {1'b0, mosaic[7:4]} + 5'd1;
            mx = px_x;
            if (mosaic[i]) begin
                if (hires_o) mx = {(px_x[9:1] - (px_x[9:1] % {4'h0, sz})), 1'b0};
                else mx = px_x - (px_x % {5'h00, sz});
            end
            bg_px[i * 12 +: 12] = bgbuf[px_bank][i][mx[8:0]];
        end
        obj_px = objbuf[px_bank][hires_o ? px_x[8:1] : px_x[7:0]];
    end
    /* verilator lint_on UNUSEDSIGNAL */
endmodule
