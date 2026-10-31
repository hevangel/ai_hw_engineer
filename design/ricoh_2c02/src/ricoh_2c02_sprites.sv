// 2C02 OAM, secondary OAM, cycle-sequenced sprite evaluation, sprite
// pattern fetch addressing and the eight sprite output units.
module ricoh_2c02_sprites (
    input  logic clk, rst_n,
    input  logic dot_ce,
    input  logic [8:0] dot, line,
    input  logic eval_line,          // visible line (0-239) with rendering on
    input  logic fetch_line,         // visible or pre-render line with rendering on
    input  logic pre_line,
    input  logic tall,               // PPUCTRL.5: 8x16 sprites
    input  logic table_sel,          // PPUCTRL.3: 8x8 sprite pattern table
    input  logic show,               // PPUMASK.4
    input  logic show_left,          // PPUMASK.2
    // OAM port from the register block
    input  logic oam_we,
    input  logic [7:0] oam_addr,
    input  logic [7:0] oam_wdata,
    output logic [7:0] oam_rdata,    // $2004 read value
    // Pattern fetch
    output logic [13:0] fetch_addr,
    input  logic [7:0] vram_rdata,
    output logic overflow_set,       // pulse: set PPUSTATUS.5
    // Pixel for dot x = dot - 1
    output logic [1:0] pix,
    output logic [1:0] pal,
    output logic behind,
    output logic zero                // pixel comes from OAM sprite 0
);
    logic [7:0] oam [0:255];
    logic [7:0] sec [0:31];
    logic [7:0] bus;                 // OAM data latch during evaluation
    logic [5:0] n;
    logic [1:0] m;
    logic [3:0] found;
    logic done, ovf_mode, zero_next, zero_line;
    logic [1:0] ovf_left;
    logic [8:0] diff;
    logic in_range;
    logic [7:0] unit_x [0:7];
    logic [7:0] unit_lo [0:7];
    logic [7:0] unit_hi [0:7];
    logic [7:0] unit_attr [0:7];
    logic [7:0] pat_lo;
    logic [2:0] slot;
    logic [2:0] sub;
    logic [3:0] s_y;                 // only the row bits matter for fetches
    logic [7:0] s_tile, s_attr, s_x;
    logic [3:0] row;
    logic slot_used;

    // ---- Evaluation -------------------------------------------------
    assign diff = line - {1'b0, bus};
    assign in_range = tall ? diff < 9'd16 : diff < 9'd8;

    // ---- Fetch addressing (dots 257-320) -----------------------------
    assign slot = 3'((dot - 9'd257) >> 3);
    assign sub = 3'(dot - 9'd257);
    assign s_y = sec[{slot, 2'd0}][3:0];
    assign s_tile = sec[{slot, 2'd1}];
    assign s_attr = sec[{slot, 2'd2}];
    assign s_x = sec[{slot, 2'd3}];
    assign slot_used = {1'b0, slot} < found;
    always_comb begin
        logic [3:0] r;
        r = line[3:0] - s_y;   // in-range rows differ only in the low bits
        row = r[3:0];
        if (s_attr[7]) row = tall ? ~r[3:0] : {1'b0, ~r[2:0]};
        if (!tall) fetch_addr = {1'b0, table_sel, s_tile, sub[1], row[2:0]};
        else fetch_addr = {1'b0, s_tile[0], s_tile[7:1], row[3], sub[1], row[2:0]};
    end

    function automatic logic [7:0] reverse(input logic [7:0] b);
        for (int i = 0; i < 8; i++) reverse[i] = b[7 - i];
    endfunction

    // ---- Output units --------------------------------------------------
    always_comb begin
        pix = 2'd0; pal = 2'd0; behind = 1'b0; zero = 1'b0;
        if (show && !(dot <= 9'd8 && !show_left)) begin
            for (int i = 7; i >= 0; i--) begin
                if (unit_x[i] == 0 && {unit_hi[i][7], unit_lo[i][7]} != 2'd0) begin
                    pix = {unit_hi[i][7], unit_lo[i][7]};
                    pal = unit_attr[i][1:0];
                    behind = unit_attr[i][5];
                    zero = (i == 0) && zero_line;
                end
            end
        end
    end

    // $2004 reads: secondary-OAM clear returns $FF; evaluation shows the latch.
    always_comb begin
        if (eval_line && dot >= 9'd1 && dot <= 9'd64) oam_rdata = 8'hff;
        else if (eval_line && dot >= 9'd65 && dot <= 9'd256) oam_rdata = bus;
        else oam_rdata = oam[oam_addr];
    end

    always_ff @(posedge clk) begin
        overflow_set <= 1'b0;
        if (oam_we) oam[oam_addr] <= oam_addr[1:0] == 2'd2 ? (oam_wdata & 8'he3) : oam_wdata;
        if (!rst_n) begin
            n <= '0; m <= '0; found <= '0; done <= 1'b0; ovf_mode <= 1'b0; ovf_left <= '0;
            zero_next <= 1'b0; zero_line <= 1'b0; bus <= 8'hff;
            for (int i = 0; i < 8; i++) begin
                unit_x[i] <= 8'hff; unit_lo[i] <= '0; unit_hi[i] <= '0; unit_attr[i] <= '0;
            end
        end else if (dot_ce) begin
            // Pixel shifting for visible dots.
            if (fetch_line && !pre_line && dot >= 9'd1 && dot <= 9'd256) begin
                for (int i = 0; i < 8; i++) begin
                    if (unit_x[i] != 0) unit_x[i] <= unit_x[i] - 8'd1;
                    else begin unit_lo[i] <= unit_lo[i] << 1; unit_hi[i] <= unit_hi[i] << 1; end
                end
            end
            if (eval_line) begin
                if (dot >= 9'd1 && dot <= 9'd64) begin
                    if (!dot[0]) sec[5'((dot >> 1) - 9'd1)] <= 8'hff;
                    if (dot == 9'd64) begin
                        n <= oam_addr[7:2]; m <= oam_addr[1:0]; found <= '0; done <= 1'b0;
                        ovf_mode <= 1'b0; zero_next <= 1'b0;
                    end
                end else if (dot >= 9'd65 && dot <= 9'd256) begin
                    if (dot[0]) bus <= oam[{n, m}];
                    else if (done) begin
                        n <= n + 6'd1;
                    end else if (ovf_mode) begin
                        // Read the three bytes after the overflowing Y, then stop.
                        {n, m} <= {n, m} + 8'd1;
                        if (ovf_left == 2'd1) done <= 1'b1;
                        ovf_left <= ovf_left - 2'd1;
                    end else if (found < 4'd8) begin
                        sec[{found[2:0], m}] <= bus;
                        if (m == 2'd0) begin
                            if (in_range) begin
                                m <= 2'd1;
                                if (dot == 9'd66) zero_next <= 1'b1;
                            end else begin
                                n <= n + 6'd1;
                                if (n == 6'd63) done <= 1'b1;
                            end
                        end else if (m == 2'd3) begin
                            m <= 2'd0; found <= found + 4'd1; n <= n + 6'd1;
                            if (n == 6'd63) done <= 1'b1;
                        end else m <= m + 2'd1;
                    end else begin
                        // Eight found: the hardware keeps treating OAM[n][m]
                        // as a Y coordinate and increments both n and m.
                        if (in_range) begin
                            overflow_set <= 1'b1; ovf_mode <= 1'b1; ovf_left <= 2'd3;
                            {n, m} <= {n, m} + 8'd1;
                        end else begin
                            n <= n + 6'd1; m <= m + 2'd1;
                            if (n == 6'd63) done <= 1'b1;
                        end
                    end
                end
            end
            if (fetch_line && pre_line && dot == 9'd1) found <= '0;
            // Sprite fetches: latch pattern low then high, load the unit.
            if (fetch_line && dot >= 9'd257 && dot <= 9'd320) begin
                if (dot == 9'd257) zero_line <= zero_next && !pre_line;
                if (sub == 3'd5) pat_lo <= vram_rdata;
                if (sub == 3'd7) begin
                    if (slot_used && !pre_line) begin
                        unit_x[slot] <= s_x; unit_attr[slot] <= s_attr;
                        unit_lo[slot] <= s_attr[6] ? reverse(pat_lo) : pat_lo;
                        unit_hi[slot] <= s_attr[6] ? reverse(vram_rdata) : vram_rdata;
                    end else begin
                        unit_x[slot] <= 8'hff; unit_attr[slot] <= '0;
                        unit_lo[slot] <= '0; unit_hi[slot] <= '0;
                    end
                end
            end
        end
    end
endmodule
