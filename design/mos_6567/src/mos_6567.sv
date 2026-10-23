// MOS 6567/6569 VIC-II (NMOS) and 8562/8565 (HMOS) video controller.
// One clk edge is one dot (8 per system clock). Behavior follows the pinned
// MAME per-dot model selected in spec/spec.md; see the assumption ledger.
module mos_6567 #(
    // 0 = 6569 PAL, 1 = 6567R8 NTSC, 2 = 6567R56A NTSC, 3 = 8565 PAL, 4 = 8562 NTSC
    parameter int VARIANT = 0
) (
    input  logic        clk,
    input  logic        rst_n,
    // CPU access for the current system clock; stable during its 8 dots.
    input  logic        cs_i,
    input  logic        rw_i,
    input  logic [5:0]  addr_i,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    output logic        irq_n_o,
    output logic        ba_o,
    output logic        aec_o,
    input  logic        lp_n_i,
    // Board: character ROM appears at VIC $1000-$1FFF in this bank.
    input  logic        rom_window_i,
    // Display fetches, all performed at the cycle (logic) edge.
    output logic        cycle_edge_o,
    output logic [13:0] phi1_addr_o,
    input  logic [7:0]  phi1_data_i,
    output logic        phi2_fetch_o,
    output logic [13:0] phi2_addr_o,
    input  logic [7:0]  phi2_data_i,
    output logic        color_fetch_o,
    output logic [9:0]  color_addr_o,
    input  logic [3:0]  color_data_i,
    // Pixels leave the output pipeline in drawing order.
    output logic        pixel_valid_o,
    output logic [3:0]  pixel_o,
    output logic [8:0]  pixel_row_o,
    output logic [9:0]  pixel_col_o,
    output logic [6:0]  cycle_o,
    output logic [8:0]  rasterline_o,
    output logic [3:0]  dot_o,
    output logic [7:0]  last_data_o
);
    // ---------------------------------------------------------------- timing
    localparam bit NTSC = VARIANT == 1 || VARIANT == 2 || VARIANT == 4;
    localparam bit NTSC64 = VARIANT == 2;
    localparam bit HMOS = VARIANT == 3 || VARIANT == 4;
    localparam int CPL = NTSC ? (NTSC64 ? 64 : 65) : 63;
    localparam int LINES = NTSC ? (NTSC64 ? 262 : 263) : 312;
    localparam int LINE_PIXELS = NTSC ? 512 : 504;
    localparam int FIRST_X = NTSC ? 'h19c : 'h194;
    localparam int X_STALL_PHASE = NTSC ? (NTSC64 ? 128 : 123) : 126;
    localparam int X_STALL_LENGTH = (NTSC && !NTSC64) ? 2 : 0;
    localparam int SPR_FIRST_CYCLE = NTSC ? 59 : 58;
    localparam int SPR_DMA_CYCLE = NTSC ? 56 : 55;
    localparam int SPR_DISP_CYCLE = NTSC ? (NTSC64 ? 58 : 59) : 58;
    localparam int ROW_SHIFT = NTSC ? (LINES - 'h1c) : 0;
    localparam int BLANK_END = NTSC ? 'h1db : 'h1e0;
    localparam int BURST_LENGTH = NTSC ? 0 : 2;
    // Process traits (NMOS, NMOS old 6567R56A, HMOS).
    localparam bit ASYM_EDGES = !HMOS;
    localparam bit HMOS_MC_FLOP = HMOS;
    localparam bit GREY_DOT = HMOS;
    localparam int OUTPUT_LAG = HMOS ? 4 : 3;
    localparam int MMC_SEEN = HMOS ? 2 : 3;
    localparam logic [7:0] LP_X_OFFSET = HMOS ? 8'd1 : 8'd2;
    localparam bit LP_FRAME_IRQ_ONLY = NTSC64;
    localparam logic [13:0] DMA_DELAY_IDLE = HMOS ? 14'h3807 : 14'h38ff;

    localparam logic [5:0] R_CR1 = 6'h11, R_RASTER = 6'h12, R_LPX = 6'h13, R_LPY = 6'h14;
    localparam logic [5:0] R_MSE = 6'h15, R_CR2 = 6'h16, R_MYE = 6'h17, R_MEM = 6'h18;
    localparam logic [5:0] R_IRQ = 6'h19, R_IEN = 6'h1a, R_MDP = 6'h1b, R_MMC = 6'h1c;
    localparam logic [5:0] R_MXE = 6'h1d, R_MM = 6'h1e, R_MD = 6'h1f, R_EC = 6'h20;
    localparam logic [5:0] C_B0C = 6'h21, C_MM0 = 6'h25, C_MM1 = 6'h26, C_M0C = 6'h27;

    function automatic logic [8:0] phase_x(input int phase);
        int p;
        p = phase;
        if (p >= X_STALL_PHASE)
            p = (X_STALL_PHASE - 1 > p - X_STALL_LENGTH) ? X_STALL_PHASE - 1 : p - X_STALL_LENGTH;
        phase_x = 9'((FIRST_X + 4 * p) % LINE_PIXELS);
    endfunction

    function automatic int sprite_cycle(input int i);
        sprite_cycle = (SPR_FIRST_CYCLE - 1 + 2 * i) % CPL + 1;
    endfunction

    // Dot position of a 16-dot sprite slot (>= 128 when outside every slot).
    function automatic int slot_dot(input int dot);
        int s;
        s = dot + 4 - 8 * (SPR_FIRST_CYCLE - 1);
        if (s < 0) s = s + 8 * CPL;
        slot_dot = s;
    endfunction

    function automatic logic [7:0] unused_bits(input logic [5:0] reg_index);
        unused_bits = 8'h00;
        if (reg_index == R_CR2) unused_bits = 8'hc0;
        else if (reg_index == R_MEM) unused_bits = 8'h01;
        else if (reg_index == R_IRQ) unused_bits = 8'h70;
        else if (reg_index == R_IEN) unused_bits = 8'hf0;
        else if (reg_index >= 6'h20 && reg_index < 6'h2f) unused_bits = 8'hf0;
        else if (reg_index >= 6'h2f) unused_bits = 8'hff;
    endfunction

    // Dot at which each bit of a CPU write becomes visible to the display.
    function automatic logic [31:0] seen_dots(input logic [5:0] r, input logic [2:0] d,
                                              input logic cr1_ecm);
        logic [3:0] s [8];
        for (int b = 0; b < 8; b++) s[b] = 4'd8;
        if (r == R_CR1) begin
            s[3] = 0;
            if (ASYM_EDGES) begin
                s[5] = d[1] ? 4'd0 : 4'd2;
                s[6] = d[2] ? 4'd0 : 4'd2;
            end else begin
                s[5] = d[1] ? 4'd4 : 4'd5;
                s[6] = d[2] ? 4'd4 : 4'd5;
            end
        end else if (r == R_CR2) begin
            s[3] = 0;
            s[0] = 4;
            s[1] = 4;
            s[2] = 4;
            s[4] = (!d[0] && ASYM_EDGES && cr1_ecm) ? 4'd1 : 4'd0;
        end else begin
            for (int b = 0; b < 8; b++) begin
                if (r == R_MMC) s[b] = 4'(MMC_SEEN);
                else if (r <= 6'h10) s[b] = 4;
                else if (r == R_MDP || r == R_MXE) s[b] = 2;
                else if (r >= R_EC && r < 6'h2f) s[b] = 0;
            end
        end
        seen_dots = {s[7], s[6], s[5], s[4], s[3], s[2], s[1], s[0]};
    endfunction

    // ------------------------------------------------------------------ state
    logic [46:0][7:0] reg_q, reg_d, dreg_q, dreg_d;
    logic [8:0]  rasterline_q, rasterline_d, beam_q, beam_d;
    logic [6:0]  cycle_q, cycle_d;
    logic [3:0]  pos_q, pos_d;
    logic [7:0]  last_data_q, last_data_d;
    logic [4:0]  bus_slot_q, bus_slot_d;      // 5'h1f = none
    logic        lp_q, lp_d, lp_latched_q, lp_latched_d, lp_pending_q, lp_pending_d;
    logic        ba_q, ba_d, aec_q, aec_d;
    logic [7:0]  aec_delay_q, aec_delay_d;
    logic [3:0]  irq_flags_q, irq_flags_d, irq_enable_q, irq_enable_d;
    logic        raster_irq_done_q, raster_irq_done_d;
    logic        badline_q, badline_d, badlines_en_q, badlines_en_d, display_q, display_d;
    logic [7:0]  fetch_cr1_q, fetch_cr1_d;
    logic [9:0]  vc_q, vc_d, vcbase_q, vcbase_d;
    logic [5:0]  vmli_q, vmli_d;
    logic [2:0]  rc_q, rc_d;
    logic [7:0]  refresh_q, refresh_d;
    logic [63:0][7:0] matrix_q, matrix_d;
    logic [63:0][3:0] color_q, color_d;
    logic [7:0]  spr_dma_q, spr_dma_d, spr_disp_q, spr_disp_d, spr_yff_q, spr_yff_d;
    logic [7:0][5:0] spr_mcbase_q, spr_mcbase_d, spr_mc_q, spr_mc_d;
    logic [7:0][7:0] spr_pointer_q, spr_pointer_d;
    logic [23:0][7:0] spr_byte_q, spr_byte_d;  // index 3*sprite + byte
    logic [7:0]  spr_pending_q, spr_pending_d, spr_active_q, spr_active_d, spr_halt_q, spr_halt_d;
    logic [7:0][23:0] spr_shift_q, spr_shift_d;
    logic [7:0]  spr_xphase_q, spr_xphase_d, spr_mcphase_q, spr_mcphase_d;
    logic [7:0][1:0] spr_pixel_q, spr_pixel_d;
    logic [3:0][5:0] pix_color_q, pix_color_d;
    logic [3:0][8:0] pix_row_q, pix_row_d;
    logic [3:0][9:0] pix_col_q, pix_col_d;
    logic [1:0]  pix_index_q, pix_index_d;
    logic [2:0]  pix_count_q, pix_count_d;
    logic [7:0]  color_write_q, color_write_d;
    logic [7:0][7:0] coll_mm_q, coll_mm_d, coll_md_q, coll_md_d;
    logic [2:0]  coll_index_q, coll_index_d;
    logic [3:0]  hold_mm_q, hold_mm_d, hold_md_q, hold_md_d;
    logic [8:0]  draw_row_q, draw_row_d;
    logic [6:0]  draw_cycle_q, draw_cycle_d;     // 1-based cycle being drawn
    logic [1:0][7:0]  latch_gfx_q, latch_gfx_d;
    logic [1:0][11:0] latch_vbuf_q, latch_vbuf_d;
    logic [7:0]  seq_shift_q, seq_shift_d;
    logic [11:0] seq_vbuf_q, seq_vbuf_d;
    logic        seq_count_q, seq_count_d;      // parity of the reference counter
    logic [1:0]  seq_mc_q, seq_mc_d;
    logic        seq_mcm_q, seq_mcm_d, seq_cell_mc_q, seq_cell_mc_d;
    logic [1:0]  seq_bmm_q, seq_bmm_d;
    logic [2:0]  seq_xscroll_q, seq_xscroll_d;
    logic        main_border_q, main_border_d, vert_border_q, vert_border_d;
    logic        vert_ff_q, vert_ff_d;
    // Delayed display-register fields of the previous write (seen at dot 8).
    logic        late_valid_q, late_valid_d;
    logic [5:0]  late_reg_q, late_reg_d;
    logic [7:0]  late_data_q, late_data_d, late_mask_q, late_mask_d;
    // Current cycle's write and its per-bit visibility dots.
    logic        wr_valid_q, wr_valid_d;
    logic [5:0]  wr_reg_q, wr_reg_d;
    logic [7:0]  wr_data_q, wr_data_d;
    logic [31:0] wr_seen_q, wr_seen_d;
    logic [7:0]  read_q, read_d;

    // ------------------------------------------------------- combinational
    logic [5:0]  cur_color;
    logic [7:0]  sprite_mask;
    logic [7:0][5:0] sprite_color;
    logic        fg;
    logic [8:0]  x;
    logic [7:0]  apply_mask;
    logic [5:0]  apply_reg;
    logic [7:0]  apply_data;
    logic        apply_now;
    logic [7:0]  toggled;
    logic [7:0]  cr1, cr2;
    logic [2:0]  mode;
    logic [3:0]  mcm_flop_dot;
    logic        next_mcm;
    logic [2:0]  slot;
    logic [1:0]  pair;
    logic        bit_v, latch_sel;
    logic [11:0] v;
    int          sd, si, sp_slot, lowest;
    logic [8:0]  sx;
    logic [23:0] sdata;
    logic [1:0]  spx;
    logic [7:0]  mm, md;
    logic [5:0]  selected;
    logic [3:0]  resolved;
    logic [7:0]  read_value;
    logic [5:0]  rd_reg;
    // Cycle logic.
    int          cyc;
    logic        line_start, frame_start, refresh_s, badline_ba, vc_load, matrix_s;
    logic        graphics_s, mcbase_s, spr_dma_s, yexp_s, row_end_s, spr_display_s;
    int          ptr_sprite, data_sprite;
    logic [7:0]  spr_ba_mask;
    logic [8:0]  compare;
    logic        disp_before, dma_delay, rsel, ba_low, ecm;
    logic [7:0]  fmode, chr;
    logic [13:0] addr_mode, addr_from, addr_to, gaddr, maddr, saddr;
    logic [7:0]  phi1_value;
    int          spr_i, byte_i;
    logic [8:0]  raster_x;
    logic [7:0]  lp_x;

    function automatic logic [13:0] char_address(input logic [1:0] cr, input logic [2:0] mem,
                                                 input logic [9:0] vc, input logic [7:0] c,
                                                 input logic [2:0] rc);
        logic [13:0] a;
        if (cr[0]) a = {mem[2], vc, rc};
        else a = {mem, c, rc};
        if (cr[1]) a = a & 14'h39ff;
        char_address = a;
    endfunction

    function automatic logic is_rom(input logic window, input logic [1:0] a);
        is_rom = window && a == 2'b01;
    endfunction

    always_comb begin
        reg_d = reg_q;  dreg_d = dreg_q;
        rasterline_d = rasterline_q;  beam_d = beam_q;  cycle_d = cycle_q;  pos_d = pos_q;
        last_data_d = last_data_q;  bus_slot_d = bus_slot_q;
        lp_d = lp_q;  lp_latched_d = lp_latched_q;  lp_pending_d = lp_pending_q;
        ba_d = ba_q;  aec_d = aec_q;  aec_delay_d = aec_delay_q;
        irq_flags_d = irq_flags_q;  irq_enable_d = irq_enable_q;
        raster_irq_done_d = raster_irq_done_q;
        badline_d = badline_q;  badlines_en_d = badlines_en_q;  display_d = display_q;
        fetch_cr1_d = fetch_cr1_q;  vc_d = vc_q;  vcbase_d = vcbase_q;  vmli_d = vmli_q;
        rc_d = rc_q;  refresh_d = refresh_q;  matrix_d = matrix_q;  color_d = color_q;
        spr_dma_d = spr_dma_q;  spr_disp_d = spr_disp_q;  spr_yff_d = spr_yff_q;
        spr_mcbase_d = spr_mcbase_q;  spr_mc_d = spr_mc_q;  spr_pointer_d = spr_pointer_q;
        spr_byte_d = spr_byte_q;  spr_pending_d = spr_pending_q;  spr_active_d = spr_active_q;
        spr_halt_d = spr_halt_q;  spr_shift_d = spr_shift_q;  spr_xphase_d = spr_xphase_q;
        spr_mcphase_d = spr_mcphase_q;  spr_pixel_d = spr_pixel_q;
        pix_color_d = pix_color_q;  pix_row_d = pix_row_q;  pix_col_d = pix_col_q;
        pix_index_d = pix_index_q;  pix_count_d = pix_count_q;  color_write_d = color_write_q;
        coll_mm_d = coll_mm_q;  coll_md_d = coll_md_q;  coll_index_d = coll_index_q;
        hold_mm_d = hold_mm_q;  hold_md_d = hold_md_q;
        draw_row_d = draw_row_q;  draw_cycle_d = draw_cycle_q;
        latch_gfx_d = latch_gfx_q;  latch_vbuf_d = latch_vbuf_q;
        seq_shift_d = seq_shift_q;  seq_vbuf_d = seq_vbuf_q;  seq_count_d = seq_count_q;
        seq_mc_d = seq_mc_q;  seq_mcm_d = seq_mcm_q;  seq_cell_mc_d = seq_cell_mc_q;
        seq_bmm_d = seq_bmm_q;  seq_xscroll_d = seq_xscroll_q;
        main_border_d = main_border_q;  vert_border_d = vert_border_q;  vert_ff_d = vert_ff_q;
        late_valid_d = late_valid_q;  late_reg_d = late_reg_q;  late_data_d = late_data_q;
        late_mask_d = late_mask_q;
        wr_valid_d = wr_valid_q;  wr_reg_d = wr_reg_q;  wr_data_d = wr_data_q;
        wr_seen_d = wr_seen_q;  read_d = read_q;

        pixel_valid_o = 0;  pixel_o = 0;  pixel_row_o = 0;  pixel_col_o = 0;
        cycle_edge_o = 0;  phi1_addr_o = 0;  phi2_fetch_o = 0;  phi2_addr_o = 0;
        color_fetch_o = 0;  color_addr_o = 0;
        cur_color = 0;  sprite_mask = 0;  sprite_color = '0;  fg = 0;  x = 0;
        apply_mask = 0;  apply_reg = 0;  apply_data = 0;  apply_now = 0;  toggled = 0;
        cr1 = 0;  cr2 = 0;  mode = 0;  mcm_flop_dot = 0;  next_mcm = 0;  slot = 0;  pair = 0;
        bit_v = 0;  latch_sel = 0;  v = 0;  sd = 0;  si = 0;  sp_slot = 0;  lowest = 0;
        sx = 0;  sdata = 0;  spx = 0;  mm = 0;  md = 0;  selected = 0;
        resolved = 0;  read_value = 0;  rd_reg = 0;
        cyc = 0;  line_start = 0;  frame_start = 0;  refresh_s = 0;  badline_ba = 0;
        vc_load = 0;  matrix_s = 0;  graphics_s = 0;  mcbase_s = 0;  spr_dma_s = 0;
        yexp_s = 0;  row_end_s = 0;  spr_display_s = 0;  ptr_sprite = -1;  data_sprite = -1;
        spr_ba_mask = 0;  compare = 0;  disp_before = 0;  dma_delay = 0;  rsel = 0;
        ba_low = 0;  ecm = 0;  fmode = 0;  chr = 0;  addr_mode = 0;  addr_from = 0;
        addr_to = 0;  gaddr = 0;  maddr = 0;  saddr = 0;  phi1_value = 0;
        spr_i = -1;  byte_i = 0;  raster_x = 0;  lp_x = 0;

        if (rst_n) begin
            // ========================= draw one dot of the current cycle
            if (pos_q < 4'd8) begin
                if (pos_q == 0) begin
                    // CPU access of this cycle: writes and plain reads act
                    // before any dot is drawn (the reference's order).
                    wr_valid_d = 0;
                    if (cs_i) begin
                        rd_reg = addr_i;
                        if (bus_slot_q != 5'h1f && !rw_i)
                            spr_byte_d[bus_slot_q] = data_i;
                        if (!rw_i) begin
                            if (rd_reg == R_IRQ) begin
                                irq_flags_d = irq_flags_d & ~data_i[3:0];
                            end else if (rd_reg == R_IEN) begin
                                irq_enable_d = data_i[3:0];
                            end else if (rd_reg == R_CR1 || rd_reg == R_RASTER) begin
                                reg_d[rd_reg] = data_i;
                                wr_valid_d = 1;
                                compare = {reg_d[R_CR1][7], reg_d[R_RASTER]};
                                if (!raster_irq_done_d && rasterline_q == compare) begin
                                    raster_irq_done_d = 1;
                                    irq_flags_d[0] = 1;
                                end
                                if (rasterline_q == 9'h30 && reg_d[R_CR1][4])
                                    badlines_en_d = 1;
                            end else if (rd_reg == R_MYE) begin
                                // A write just before the MCBASE cycle merges the counters.
                                if (cycle_q == 7'd16) begin
                                    for (int i = 0; i < 8; i++)
                                        if (!data_i[i] && !spr_yff_d[i])
                                            spr_mc_d[i] = (6'h2a & (spr_mcbase_d[i] & spr_mc_d[i])) |
                                                          (6'h15 & (spr_mcbase_d[i] | spr_mc_d[i]));
                                end
                                reg_d[rd_reg] = data_i;
                                wr_valid_d = 1;
                                spr_yff_d = spr_yff_d | ~data_i;
                            end else if (rd_reg == R_MM || rd_reg == R_MD ||
                                         rd_reg == R_LPX || rd_reg == R_LPY) begin
                                // Read-only.
                            end else if (rd_reg < 6'h2f) begin
                                reg_d[rd_reg] = data_i;
                                wr_valid_d = 1;
                            end
                            wr_reg_d = rd_reg;
                            wr_data_d = data_i;
                            wr_seen_d = seen_dots(rd_reg, data_i[6:4], reg_q[R_CR1][6]);
                        end else if (rd_reg != R_IRQ && rd_reg != R_MM && rd_reg != R_MD) begin
                            if (rd_reg == R_CR1) read_value = {rasterline_q[8], reg_d[R_CR1][6:0]};
                            else if (rd_reg == R_RASTER) read_value = rasterline_q[7:0];
                            else if (rd_reg == R_IEN) read_value = {4'h0, irq_enable_d};
                            else if (rd_reg < 6'h2f) read_value = reg_d[rd_reg];
                            read_value = read_value | unused_bits(rd_reg);
                            read_d = read_value;
                            if (bus_slot_q != 5'h1f) spr_byte_d[bus_slot_q] = read_value;
                        end
                    end
                    if (draw_cycle_q == 7'(SPR_DISP_CYCLE))
                        spr_pending_d = spr_disp_d;
                    // Fields of the previous write seen at its cycle end.
                    if (late_valid_q) begin
                        apply_now = 1;
                        apply_reg = late_reg_q;
                        apply_data = late_data_q;
                        apply_mask = late_mask_q;
                    end
                    late_valid_d = 0;
                end

                // Apply display-register bits whose visibility dot is now.
                for (int pass = 0; pass < 2; pass++) begin
                    if (pass == 1) begin
                        apply_now = 0;
                        apply_mask = 0;
                        if (wr_valid_d) begin
                            for (int b = 0; b < 8; b++)
                                if (wr_seen_d[4*b +: 4] == pos_q) apply_mask[b] = 1;
                            apply_now = apply_mask != 0;
                            apply_reg = wr_reg_d;
                            apply_data = wr_data_d;
                        end
                    end
                    if (apply_now) begin
                        if (apply_reg == R_MMC) begin
                            toggled = dreg_d[R_MMC] ^ apply_data;
                            if (HMOS_MC_FLOP) begin
                                spr_mcphase_d = spr_mcphase_d ^ (toggled & spr_xphase_d);
                                spr_mcphase_d = spr_mcphase_d | (toggled & spr_xphase_d & ~apply_data);
                            end else begin
                                spr_mcphase_d = spr_mcphase_d & ~toggled;
                            end
                        end
                        if (apply_reg >= R_EC && apply_reg < 6'h2f)
                            color_write_d = {2'b00, apply_reg};
                        dreg_d[apply_reg] = (dreg_d[apply_reg] & ~apply_mask) | (apply_data & apply_mask);
                    end
                end

                // ---- dot controls from the display registers
                cr1 = dreg_d[R_CR1];
                cr2 = dreg_d[R_CR2];
                mode = {cr1[6], cr1[5], cr2[4]};
                mcm_flop_dot = 4'd3 + ((!cr2[4] && ASYM_EDGES && cr1[6]) ? 4'd1 : 4'd0);
                x = phase_x(2 * (int'(draw_cycle_q) - 1) + (pos_q >= 4 ? 1 : 0)) + 9'(pos_q[1:0]);

                // ---- border unit
                if (x == (cr2[3] ? 9'd344 : 9'd335))
                    main_border_d = 1;
                if (x == (cr2[3] ? 9'd24 : 9'd31)) begin
                    if (rasterline_q == (cr1[3] ? 9'd251 : 9'd247))
                        vert_ff_d = 1;
                    vert_border_d = vert_ff_d;
                    if (!vert_border_d)
                        main_border_d = 0;
                end

                // ---- graphics sequencer
                slot = pos_q[2:0];
                next_mcm = cr2[4];
                if ({1'b0, pos_q} == {1'b0, mcm_flop_dot}) begin
                    if (next_mcm && !seq_mcm_d)
                        seq_count_d = 1;
                    seq_mcm_d = next_mcm;
                end
                if (draw_cycle_q >= 7'd16 && draw_cycle_q <= 7'd55 && !vert_border_d)
                    seq_xscroll_d = cr2[2:0];
                if (slot - 3'd4 == seq_xscroll_d) begin
                    latch_sel = slot >= 3'd4 ? 1'b0 : 1'b1;
                    seq_shift_d = latch_gfx_d[latch_sel];
                    seq_vbuf_d = latch_vbuf_d[latch_sel];
                    seq_count_d = 0;
                    seq_cell_mc_d = seq_bmm_d[1] || seq_vbuf_d[11];
                end
                v = seq_vbuf_d;
                if (seq_mcm_d && seq_cell_mc_d) begin
                    if (!seq_count_d)
                        seq_mc_d = seq_shift_d[7:6];
                end else begin
                    seq_mc_d = {seq_shift_d[7], 1'b0};
                end
                seq_count_d = !seq_count_d;
                seq_shift_d = {seq_shift_d[6:0], 1'b0};
                seq_bmm_d = {seq_bmm_d[0], cr1[5]};
                bit_v = seq_mc_d[1];
                pair = seq_mc_d;
                fg = 0;
                cur_color = 0;
                case (mode)
                    3'd0: begin
                        fg = bit_v;
                        cur_color = bit_v ? {2'b00, v[11:8]} : C_B0C;
                    end
                    3'd1: begin
                        if (v[11]) begin
                            fg = pair[1];
                            cur_color = (pair == 2'd3) ? {3'b000, v[10:8]} : C_B0C + 6'(pair);
                        end else begin
                            fg = bit_v;
                            cur_color = bit_v ? {3'b000, v[10:8]} : C_B0C;
                        end
                    end
                    3'd2: begin
                        fg = bit_v;
                        cur_color = bit_v ? {2'b00, v[7:4]} : {2'b00, v[3:0]};
                    end
                    3'd3: begin
                        fg = pair[1];
                        case (pair)
                            2'd0: cur_color = C_B0C;
                            2'd1: cur_color = {2'b00, v[7:4]};
                            2'd2: cur_color = {2'b00, v[3:0]};
                            default: cur_color = {2'b00, v[11:8]};
                        endcase
                    end
                    3'd4: begin
                        fg = bit_v;
                        cur_color = bit_v ? {2'b00, v[11:8]} : C_B0C + {4'b0000, v[7:6]};
                    end
                    3'd5: fg = v[11] ? pair[1] : bit_v;
                    3'd6: fg = bit_v;
                    default: fg = pair[1];
                endcase

                // ---- sprite sequencer
                sd = slot_dot(8 * (int'(draw_cycle_q) - 1) + int'(pos_q));
                if (sd < 128) begin
                    si = sd / 16;
                    sp_slot = sd % 16;
                    if (sp_slot == 3) spr_halt_d[si] = 1;
                    else if (sp_slot == 10) spr_active_d[si] = 0;
                    else if (sp_slot == 12)
                        spr_shift_d[si] = {spr_byte_d[3*si], spr_byte_d[3*si+1], spr_byte_d[3*si+2]};
                    else if (sp_slot == 15) spr_halt_d[si] = 0;
                end
                sprite_mask = 0;
                if (spr_pending_d != 0 || spr_active_d != 0) begin
                    for (int i = 0; i < 8; i++) begin
                        if (spr_pending_d[i] && !spr_active_d[i] && !spr_halt_d[i]) begin
                            sx = {dreg_d[6'h10][i], dreg_d[2*i]};
                            if (sx == x) begin
                                spr_active_d[i] = 1;
                                spr_xphase_d[i] = 0;
                                spr_mcphase_d[i] = 1;
                            end
                        end
                        if (spr_active_d[i]) begin
                            if (spr_shift_d[i] == 0 && spr_pixel_d[i] == 0) begin
                                spr_active_d[i] = 0;
                            end else begin
                                if (!spr_halt_d[i]) begin
                                    sdata = spr_shift_d[i];
                                    if (!spr_xphase_d[i]) begin
                                        if (dreg_d[R_MMC][i]) begin
                                            if (spr_mcphase_d[i])
                                                spr_pixel_d[i] = sdata[23:22];
                                            spr_mcphase_d[i] = !spr_mcphase_d[i];
                                        end else if (!HMOS_MC_FLOP || spr_mcphase_d[i]) begin
                                            spr_pixel_d[i] = {sdata[23], 1'b0};
                                        end else begin
                                            spr_mcphase_d[i] = 1;
                                        end
                                        spr_shift_d[i] = {sdata[22:0], 1'b0};
                                    end
                                    if (dreg_d[R_MXE][i])
                                        spr_xphase_d[i] = !spr_xphase_d[i];
                                    else
                                        spr_xphase_d[i] = 0;
                                end
                                // A halted sprite shows its frozen pixel as hires.
                                spx = (spr_halt_d[i] || sd == 16 * i + 2) ?
                                      {spr_pixel_d[i][1], 1'b0} : spr_pixel_d[i];
                                if (spx != 0) begin
                                    sprite_mask[i] = 1;
                                    sprite_color[i] = (spx == 2'd1) ? C_MM0 :
                                                      (spx == 2'd3) ? C_MM1 : C_M0C + 6'(i);
                                end
                            end
                        end
                    end
                end

                // ---- collision unit (8-dot lag ring)
                mm = ((sprite_mask & (sprite_mask - 8'd1)) != 0) ? sprite_mask : 8'h00;
                md = (sprite_mask != 0 && fg) ? sprite_mask : 8'h00;
                if (coll_mm_d[coll_index_d] != 0 && hold_mm_d == 0) begin
                    if (reg_d[R_MM] == 0) irq_flags_d[2] = 1;
                    reg_d[R_MM] = reg_d[R_MM] | coll_mm_d[coll_index_d];
                end
                if (coll_md_d[coll_index_d] != 0 && hold_md_d == 0) begin
                    if (reg_d[R_MD] == 0) irq_flags_d[1] = 1;
                    reg_d[R_MD] = reg_d[R_MD] | coll_md_d[coll_index_d];
                end
                if (hold_mm_d != 0) hold_mm_d = hold_mm_d - 4'd1;
                if (hold_md_d != 0) hold_md_d = hold_md_d - 4'd1;
                coll_mm_d[coll_index_d] = mm;
                coll_md_d[coll_index_d] = md;
                coll_index_d = coll_index_d + 3'd1;

                // ---- priority, border and blanking
                if (sprite_mask != 0) begin
                    lowest = 0;
                    for (int i = 7; i >= 0; i--)
                        if (sprite_mask[i]) lowest = i;
                    if (!(fg && dreg_d[R_MDP][lowest]))
                        cur_color = sprite_color[lowest];
                end
                if (main_border_d)
                    cur_color = R_EC;
                if (int'(x) >= BLANK_END && int'(x) < BLANK_END + BURST_LENGTH)
                    cur_color = 6'h01;
                else if (int'(x) > 'h17c && int'(x) < BLANK_END)
                    cur_color = 6'h00;

                // ---- output stage (process-dependent lag)
                if (int'(pix_count_d) == OUTPUT_LAG) begin
                    selected = pix_color_d[pix_index_d];
                    if (GREY_DOT && {2'b00, selected} == color_write_d)
                        resolved = 4'hf;
                    else if (selected < 6'h10)
                        resolved = selected[3:0];
                    else
                        resolved = dreg_d[selected][3:0];
                    pixel_valid_o = 1;
                    pixel_o = resolved;
                    pixel_row_o = pix_row_d[pix_index_d];
                    pixel_col_o = pix_col_d[pix_index_d];
                end else begin
                    pix_count_d = pix_count_d + 3'd1;
                end
                pix_color_d[pix_index_d] = cur_color;
                pix_row_d[pix_index_d] = draw_row_q;
                pix_col_d[pix_index_d] = 10'(8 * (int'(draw_cycle_q) - 1) + int'(pos_q));
                pix_index_d = (int'(pix_index_d) == OUTPUT_LAG - 1) ? 2'd0 : pix_index_d + 2'd1;
                color_write_d = 8'hff;

                // ---- collision/interrupt register reads see dots 0..3
                if (pos_q == 3 && cs_i && rw_i &&
                    (addr_i == R_IRQ || addr_i == R_MM || addr_i == R_MD)) begin
                    if (addr_i == R_IRQ)
                        read_value = {((irq_flags_d & irq_enable_d) != 0), 3'b111, irq_flags_d};
                    else
                        read_value = reg_d[addr_i];
                    read_d = read_value;
                    if (addr_i == R_MM) begin
                        reg_d[R_MM] = 0;
                        hold_mm_d = 4'd12;
                    end else if (addr_i == R_MD) begin
                        reg_d[R_MD] = 0;
                        hold_md_d = 4'd12;
                    end
                    if (bus_slot_q != 5'h1f) spr_byte_d[bus_slot_q] = read_value;
                end

                // Bits seen at the cycle end wait for the next cycle's dot 0.
                if (pos_q == 7 && wr_valid_d) begin
                    late_valid_d = 0;
                    late_mask_d = 0;
                    for (int b = 0; b < 8; b++)
                        if (wr_seen_d[4*b +: 4] == 4'd8) late_mask_d[b] = 1;
                    late_valid_d = late_mask_d != 0;
                    late_reg_d = wr_reg_d;
                    late_data_d = wr_data_d;
                    wr_valid_d = 0;
                end
            end

            // ========================= cycle logic after the last dot
            if (pos_q >= 4'd7) begin
                cycle_edge_o = 1;
                cyc = int'(cycle_q);
                lp_d = lp_n_i;
                if (lp_q && !lp_n_i)
                    lp_pending_d = 1;
                line_start = cyc == 1;
                frame_start = cyc == 2;
                refresh_s = cyc >= 11 && cyc <= 15;
                badline_ba = cyc >= 12 && cyc <= 54;
                vc_load = cyc == 14;
                matrix_s = cyc >= 15 && cyc <= 54;
                graphics_s = cyc >= 16 && cyc <= 55;
                mcbase_s = cyc == 16;
                spr_dma_s = cyc == SPR_DMA_CYCLE || cyc == SPR_DMA_CYCLE + 1;
                yexp_s = cyc == 56;
                row_end_s = cyc == 58;
                spr_display_s = cyc == SPR_DISP_CYCLE;
                ptr_sprite = -1;
                data_sprite = -1;
                spr_ba_mask = 0;
                for (int i = 0; i < 8; i++) begin
                    if (cyc == sprite_cycle(i)) ptr_sprite = i;
                    else if (cyc == sprite_cycle(i) % CPL + 1) data_sprite = i;
                    if (((cyc - (sprite_cycle(i) - 3) + 2 * CPL) % CPL) < 5)
                        spr_ba_mask[i] = 1;
                end

                aec_delay_d = {aec_delay_d[6:0], ba_d};
                aec_d = 0;
                if (line_start) begin
                    beam_d = (int'(beam_d) == LINES - 1) ? 9'd0 : beam_d + 9'd1;
                    if (beam_d != 0) rasterline_d = beam_d;
                end else if (frame_start) begin
                    if (beam_d == 0) begin
                        rasterline_d = 0;
                        vcbase_d = 0;
                        refresh_d = 8'hff;
                        badlines_en_d = 0;
                        lp_latched_d = 0;
                        if (!lp_d) begin
                            lp_pending_d = 0;
                            lp_latched_d = 1;
                            reg_d[R_LPX] = 8'hd1;
                            reg_d[R_LPY] = 8'h00;
                            irq_flags_d[3] = 1;
                        end
                    end
                end

                compare = {reg_d[R_CR1][7], reg_d[R_RASTER]};
                if (rasterline_d != compare) begin
                    raster_irq_done_d = 0;
                end else if (!line_start) begin
                    if (!raster_irq_done_d) begin
                        raster_irq_done_d = 1;
                        irq_flags_d[0] = 1;
                    end
                end

                disp_before = display_d;
                if (rasterline_d == 9'h30 && reg_d[R_CR1][4])
                    badlines_en_d = 1;
                badline_d = badlines_en_d && rasterline_d >= 9'h30 && rasterline_d <= 9'hf7 &&
                            rasterline_d[2:0] == reg_d[R_CR1][2:0];
                if (badline_d) display_d = 1;
                dma_delay = !disp_before && display_d;

                rsel = reg_d[R_CR1][3];
                if (rasterline_d == (rsel ? 9'd51 : 9'd55) && reg_d[R_CR1][4]) begin
                    vert_ff_d = 0;
                    vert_border_d = 0;
                end
                if (rasterline_d == (rsel ? 9'd251 : 9'd247))
                    vert_ff_d = 1;
                if (line_start)
                    vert_border_d = vert_ff_d;

                if (vc_load) begin
                    vc_d = vcbase_d;
                    vmli_d = 0;
                    if (badline_d) rc_d = 0;
                end else if (mcbase_s) begin
                    for (int i = 0; i < 8; i++) begin
                        spr_yff_d[i] = spr_yff_d[i] | !reg_d[R_MYE][i];
                        if (spr_yff_d[i]) begin
                            spr_mcbase_d[i] = spr_mc_d[i];
                            if (spr_mcbase_d[i] == 6'd63) spr_dma_d[i] = 0;
                        end
                    end
                end else if (spr_dma_s) begin
                    for (int i = 0; i < 8; i++) begin
                        if (reg_d[R_MSE][i] && !spr_dma_d[i] && reg_d[1 + 2*i] == rasterline_d[7:0]) begin
                            spr_dma_d[i] = 1;
                            spr_mcbase_d[i] = 0;
                            spr_yff_d[i] = 1;
                        end
                    end
                end else if (row_end_s) begin
                    if (rc_d == 3'd7) begin
                        vcbase_d = vc_d;
                        display_d = 0;
                    end
                    if (badline_d || display_d) begin
                        display_d = 1;
                        rc_d = rc_d + 3'd1;
                    end
                end

                if (spr_display_s) begin
                    for (int i = 0; i < 8; i++) begin
                        spr_mc_d[i] = spr_mcbase_d[i];
                        if (spr_dma_d[i]) begin
                            if (reg_d[R_MSE][i] && reg_d[1 + 2*i] == rasterline_d[7:0])
                                spr_disp_d[i] = 1;
                        end else begin
                            spr_disp_d[i] = 0;
                        end
                    end
                end

                // ---- phase-one fetch
                if (graphics_s) begin
                    fmode = ASYM_EDGES ? (reg_d[R_CR1] | (fetch_cr1_d & 8'h60)) : fetch_cr1_d;
                    ecm = fmode[6];
                    latch_gfx_d[1] = latch_gfx_d[0];
                    latch_vbuf_d[1] = latch_vbuf_d[0];
                    if (disp_before) begin
                        chr = matrix_d[vmli_d];
                        addr_mode = char_address(fmode[6:5], reg_d[R_MEM][3:1], vc_d, chr, rc_d);
                        gaddr = addr_mode;
                        if (ASYM_EDGES && ((reg_d[R_CR1] ^ fetch_cr1_d) & 8'h20) != 0) begin
                            addr_from = char_address(fetch_cr1_d[6:5], reg_d[R_MEM][3:1], vc_d, chr, rc_d);
                            addr_to = char_address(reg_d[R_CR1][6:5], reg_d[R_MEM][3:1], vc_d, chr, rc_d);
                            if (!is_rom(rom_window_i, addr_from[13:12]) && is_rom(rom_window_i, addr_to[13:12]))
                                gaddr = {addr_to[13:8], addr_from[7:0]};
                        end
                        phi1_addr_o = gaddr;
                        phi1_value = phi1_data_i;
                        latch_gfx_d[0] = phi1_value;
                        latch_vbuf_d[0] = {color_d[vmli_d], chr};
                        vmli_d = vmli_d + 6'd1;
                        vc_d = vc_d + 10'd1;
                    end else begin
                        phi1_addr_o = ecm ? 14'h39ff : (dma_delay ? DMA_DELAY_IDLE : 14'h3fff);
                        phi1_value = phi1_data_i;
                        latch_gfx_d[0] = phi1_value;
                        latch_vbuf_d[0] = 0;
                    end
                    if (vert_border_d) begin
                        latch_gfx_d[0] = 0;
                        latch_vbuf_d[0] = latch_vbuf_d[1];
                    end
                end else begin
                    latch_gfx_d[1] = latch_gfx_d[0];
                    latch_vbuf_d[1] = latch_vbuf_d[0];
                    latch_gfx_d[0] = 0;
                    if (refresh_s) begin
                        phi1_addr_o = {6'h3f, refresh_d};
                        refresh_d = refresh_d - 8'd1;
                    end else if (ptr_sprite >= 0) begin
                        phi1_addr_o = {reg_d[R_MEM][7:4], 7'b1111111, 3'(ptr_sprite)};
                        spr_pointer_d[ptr_sprite] = phi1_data_i;
                    end else if (data_sprite >= 0) begin
                        if (spr_dma_d[data_sprite]) begin
                            phi1_addr_o = {spr_pointer_d[data_sprite], spr_mc_d[data_sprite]};
                            spr_byte_d[3*data_sprite + 1] = phi1_data_i;
                            spr_mc_d[data_sprite] = spr_mc_d[data_sprite] + 6'd1;
                        end else begin
                            phi1_addr_o = 14'h3fff;
                            spr_byte_d[3*data_sprite + 1] = phi1_data_i;
                        end
                    end else begin
                        phi1_addr_o = 14'h3fff;
                    end
                    phi1_value = phi1_data_i;
                end
                last_data_d = phi1_data_i;

                ba_low = (badline_d && badline_ba) || ((spr_dma_d & spr_ba_mask) != 0);
                if (ba_d != !ba_low) begin
                    ba_d = !ba_low;
                    if (ba_d) aec_delay_d = 8'hff;
                end
                fetch_cr1_d = reg_d[R_CR1];
                aec_d = aec_delay_d[2];

                if (yexp_s) begin
                    for (int i = 0; i < 8; i++)
                        if (reg_d[R_MYE][i] && spr_dma_d[i])
                            spr_yff_d[i] = !spr_yff_d[i];
                end

                // ---- phase-two fetches (only while the VIC owns the bus)
                if (badline_d && matrix_s) begin
                    maddr = {reg_d[R_MEM][7:4], vc_d};
                    color_fetch_o = 1;
                    color_addr_o = maddr[9:0];
                    color_d[vmli_d] = color_data_i;
                    if (aec_d) begin
                        matrix_d[vmli_d] = 8'hff;
                    end else begin
                        phi2_fetch_o = 1;
                        phi2_addr_o = maddr;
                        matrix_d[vmli_d] = phi2_data_i;
                        last_data_d = phi2_data_i;
                    end
                end
                bus_slot_d = 5'h1f;
                spr_i = ptr_sprite >= 0 ? ptr_sprite : data_sprite;
                if (spr_i >= 0) begin
                    byte_i = ptr_sprite >= 0 ? 0 : 2;
                    if (spr_dma_d[spr_i]) begin
                        saddr = {spr_pointer_d[spr_i], spr_mc_d[spr_i]};
                        if (aec_d) begin
                            spr_byte_d[3*spr_i + byte_i] = 8'hff;
                        end else begin
                            phi2_fetch_o = 1;
                            phi2_addr_o = saddr;
                            spr_byte_d[3*spr_i + byte_i] = phi2_data_i;
                            last_data_d = phi2_data_i;
                        end
                        spr_mc_d[spr_i] = spr_mc_d[spr_i] + 6'd1;
                    end else begin
                        spr_byte_d[3*spr_i + byte_i] = 8'hff;
                        bus_slot_d = 5'(3*spr_i + byte_i);
                    end
                end

                draw_row_d = 9'((int'(beam_d) + ROW_SHIFT) % LINES);
                draw_cycle_d = cycle_q;
                pos_d = 0;

                // Light-pen capture at the current cycle's raster position.
                if (lp_pending_d) begin
                    lp_pending_d = 0;
                    if (!lp_latched_d) begin
                        lp_latched_d = 1;
                        if (!(int'(rasterline_d) == LINES - 1 && cyc != 1)) begin
                            raster_x = phase_x(2 * (cyc - 1));
                            lp_x = {raster_x[8:3], 2'b00} + LP_X_OFFSET;
                            reg_d[R_LPX] = lp_x;
                            reg_d[R_LPY] = rasterline_d[7:0];
                            if (!LP_FRAME_IRQ_ONLY) irq_flags_d[3] = 1;
                        end
                    end
                end
                cycle_d = (cyc == CPL) ? 7'd1 : cycle_q + 7'd1;
            end else begin
                pos_d = pos_q + 4'd1;
            end
        end
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization equals the reference's
        // device_start/device_reset values (cycle 14 of line 0, pen high).
        if (!rst_n) begin
            reg_q <= '0;  dreg_q <= '0;
            rasterline_q <= 0;  beam_q <= 0;  cycle_q <= 7'd14;  pos_q <= 4'd8;
            last_data_q <= 0;  bus_slot_q <= 5'h1f;
            lp_q <= 1;  lp_latched_q <= 0;  lp_pending_q <= 0;
            ba_q <= 1;  aec_q <= 1;  aec_delay_q <= 8'hff;
            irq_flags_q <= 0;  irq_enable_q <= 0;  raster_irq_done_q <= 0;
            badline_q <= 0;  badlines_en_q <= 0;  display_q <= 0;  fetch_cr1_q <= 0;
            vc_q <= 0;  vcbase_q <= 0;  vmli_q <= 0;  rc_q <= 3'd7;  refresh_q <= 8'hff;
            matrix_q <= '0;  color_q <= '0;
            spr_dma_q <= 0;  spr_disp_q <= 0;  spr_yff_q <= 8'hff;
            spr_mcbase_q <= '0;  spr_mc_q <= '0;  spr_pointer_q <= '0;  spr_byte_q <= '0;
            spr_pending_q <= 0;  spr_active_q <= 0;  spr_halt_q <= 0;  spr_shift_q <= '0;
            spr_xphase_q <= 0;  spr_mcphase_q <= 0;  spr_pixel_q <= '0;
            pix_color_q <= '0;  pix_row_q <= '0;  pix_col_q <= '0;
            pix_index_q <= 0;  pix_count_q <= 0;  color_write_q <= 8'hff;
            coll_mm_q <= '0;  coll_md_q <= '0;  coll_index_q <= 0;  hold_mm_q <= 0;  hold_md_q <= 0;
            draw_row_q <= 0;  draw_cycle_q <= 7'd1;
            latch_gfx_q <= '0;  latch_vbuf_q <= '0;
            seq_shift_q <= 0;  seq_vbuf_q <= 0;  seq_count_q <= 0;  seq_mc_q <= 0;
            seq_mcm_q <= 0;  seq_cell_mc_q <= 0;  seq_bmm_q <= 0;  seq_xscroll_q <= 0;
            main_border_q <= 1;  vert_border_q <= 1;  vert_ff_q <= 1;
            late_valid_q <= 0;  late_reg_q <= 0;  late_data_q <= 0;  late_mask_q <= 0;
            wr_valid_q <= 0;  wr_reg_q <= 0;  wr_data_q <= 0;  wr_seen_q <= 0;  read_q <= 0;
        end else begin
            reg_q <= reg_d;  dreg_q <= dreg_d;
            rasterline_q <= rasterline_d;  beam_q <= beam_d;  cycle_q <= cycle_d;  pos_q <= pos_d;
            last_data_q <= last_data_d;  bus_slot_q <= bus_slot_d;
            lp_q <= lp_d;  lp_latched_q <= lp_latched_d;  lp_pending_q <= lp_pending_d;
            ba_q <= ba_d;  aec_q <= aec_d;  aec_delay_q <= aec_delay_d;
            irq_flags_q <= irq_flags_d;  irq_enable_q <= irq_enable_d;
            raster_irq_done_q <= raster_irq_done_d;
            badline_q <= badline_d;  badlines_en_q <= badlines_en_d;  display_q <= display_d;
            fetch_cr1_q <= fetch_cr1_d;
            vc_q <= vc_d;  vcbase_q <= vcbase_d;  vmli_q <= vmli_d;  rc_q <= rc_d;
            refresh_q <= refresh_d;  matrix_q <= matrix_d;  color_q <= color_d;
            spr_dma_q <= spr_dma_d;  spr_disp_q <= spr_disp_d;  spr_yff_q <= spr_yff_d;
            spr_mcbase_q <= spr_mcbase_d;  spr_mc_q <= spr_mc_d;  spr_pointer_q <= spr_pointer_d;
            spr_byte_q <= spr_byte_d;  spr_pending_q <= spr_pending_d;
            spr_active_q <= spr_active_d;  spr_halt_q <= spr_halt_d;  spr_shift_q <= spr_shift_d;
            spr_xphase_q <= spr_xphase_d;  spr_mcphase_q <= spr_mcphase_d;
            spr_pixel_q <= spr_pixel_d;
            pix_color_q <= pix_color_d;  pix_row_q <= pix_row_d;  pix_col_q <= pix_col_d;
            pix_index_q <= pix_index_d;  pix_count_q <= pix_count_d;
            color_write_q <= color_write_d;
            coll_mm_q <= coll_mm_d;  coll_md_q <= coll_md_d;  coll_index_q <= coll_index_d;
            hold_mm_q <= hold_mm_d;  hold_md_q <= hold_md_d;
            draw_row_q <= draw_row_d;  draw_cycle_q <= draw_cycle_d;
            latch_gfx_q <= latch_gfx_d;  latch_vbuf_q <= latch_vbuf_d;
            seq_shift_q <= seq_shift_d;  seq_vbuf_q <= seq_vbuf_d;  seq_count_q <= seq_count_d;
            seq_mc_q <= seq_mc_d;  seq_mcm_q <= seq_mcm_d;  seq_cell_mc_q <= seq_cell_mc_d;
            seq_bmm_q <= seq_bmm_d;  seq_xscroll_q <= seq_xscroll_d;
            main_border_q <= main_border_d;  vert_border_q <= vert_border_d;
            vert_ff_q <= vert_ff_d;
            late_valid_q <= late_valid_d;  late_reg_q <= late_reg_d;
            late_data_q <= late_data_d;  late_mask_q <= late_mask_d;
            wr_valid_q <= wr_valid_d;  wr_reg_q <= wr_reg_d;  wr_data_q <= wr_data_d;
            wr_seen_q <= wr_seen_d;  read_q <= read_d;
        end
    end

    // Control bits consumed by other units, and sub-cell raster X bits.
    logic unused_bits_sink;
    assign unused_bits_sink = ^{cr1[7], cr1[4], cr1[2:0], cr2[7:5], raster_x[2:0], phi1_value,
                               fmode[7], fmode[4:0], addr_from[11:8], addr_to[7:0]};

    assign data_o = read_q;
    assign irq_n_o = !((irq_flags_q & irq_enable_q) != 0);
    assign ba_o = ba_q;
    assign aec_o = aec_q;
    assign cycle_o = cycle_q;
    assign rasterline_o = rasterline_q;
    assign dot_o = pos_q;
    assign last_data_o = last_data_q;

`ifdef FORMAL
    `include "mos_6567_props.sv"
`endif
endmodule
