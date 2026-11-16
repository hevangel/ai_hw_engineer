// IBM VGA graphics controller (VGAXGA p.2-78 to 2-88, HITR p.66-75).
//
// Copied from ega_graphics_ctrl.sv. The EGA had two chips of two planes
// each with a position register; the VGA has one controller for the four
// maps, so the position register is gone, Read Map Select is 2 bits,
// write mode 3 exists, the Graphics Mode register has the 256-colour bit,
// and every register is readable.
module vga_graphics_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        addr_we,
    input  logic        data_we,
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata_idx,     // 3CE read
    output logic [7:0]  rdata,         // 3CF read
    // processor write data per map
    input  logic [7:0]  cpu_d,
    output logic [31:0] wd,            // map 3..0
    // processor read
    input  logic [31:0] rd,            // map 3..0 at the plane address
    input  logic        a0,
    input  logic        chain4,
    input  logic [1:0]  chain4_map,
    input  logic        latch_we,
    output logic [7:0]  rd_data,
    // serializer: the four maps of two fetched characters
    input  logic        shift_load,
    input  logic [31:0] e_p, n_p,
    input  logic        e_odd, n_odd,
    output logic [35:0] e_ser,         // dot j: [4j+3:4j] = C3..C0
    output logic [35:0] n_ser,
    // register views
    output logic [71:0] dbg_regs,
    output logic [3:0]  idx,
    output logic [31:0] lat
);
    logic [7:0] regs [0:8];
    logic [7:0] wmask;

    // ASSUMPTION V7: undefined bits are not stored
    always_comb begin
        unique case (idx)
            4'd3:    wmask = 8'h1F;
            4'd4:    wmask = 8'h03;
            4'd5:    wmask = 8'h7B;
            4'd8:    wmask = 8'hFF;
            default: wmask = 8'h0F;
        endcase
    end

    assign dbg_regs = {regs[8], regs[7], regs[6], regs[5], regs[4], regs[3],
                       regs[2], regs[1], regs[0]};
    assign rdata_idx = {4'd0, idx};
    assign rdata = (idx <= 4'd8) ? regs[idx] : 8'h00;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 4'd0;
            for (int i = 0; i < 9; i++) regs[i] <= 8'h00;
        end else begin
            if (addr_we) idx <= wdata[3:0];
            if (data_we && idx <= 4'd8) regs[idx] <= wdata & wmask;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n)        lat <= '0;
        else if (latch_we) lat <= rd;
    end

    // ------------------------------------------------------ write path
    logic [7:0] rot;
    logic [1:0] wm, fn;
    assign wm  = regs[5][1:0];
    assign fn  = regs[3][4:3];
    assign rot = (cpu_d >> regs[3][2:0]) | (cpu_d << (4'd8 - {1'b0, regs[3][2:0]}));  // p.2-82

    function automatic logic [7:0] wpath(input logic [1:0] n, input logic [7:0] l);
        logic [7:0] v, m;
        m = regs[8];
        unique case (wm)
            2'd0: v = regs[1][{1'b0, n}] ? {8{regs[0][{1'b0, n}]}} : rot;
            2'd2: v = {8{cpu_d[{1'b0, n}]}};
            2'd3: begin
                v = {8{regs[0][{1'b0, n}]}};          // p.2-85: Enable Set/Reset ignored
                m = regs[8] & rot;
            end
            default: v = l;
        endcase
        unique case (fn)
            2'd0: ;
            2'd1: v = v & l;
            2'd2: v = v | l;
            2'd3: v = v ^ l;
        endcase
        v = (v & m) | (l & ~m);
        wpath = (wm == 2'd1) ? l : v;
    endfunction

    always_comb
        for (int n = 0; n < 4; n++) wd[8*n +: 8] = wpath(2'(n), lat[8*n +: 8]);

    // ------------------------------------------------------- read path
    logic [1:0] map;
    logic [7:0] cmp;
    always_comb begin
        if (chain4)         map = chain4_map;
        else if (regs[5][4]) map = {regs[4][1], a0};
        else                map = regs[4][1:0];
        cmp = 8'hFF;
        for (int n = 0; n < 4; n++)
            if (regs[7][n]) cmp = cmp & ~(rd[8*n +: 8] ^ {8{regs[2][n]}});   // p.2-87
        rd_data = regs[5][3] ? cmp : rd[8*map +: 8];
    end

    // ------------------------------------------------------ serializer
    function automatic logic [35:0] ser(input logic [31:0] p, input logic odd);
        logic [35:0] o;
        logic [7:0]  by;
        o = 36'd0;
        for (int j = 0; j < 8; j++) begin
            if (regs[5][6]) begin
                // ASSUMPTION V17: dot 2i = map i high nibble, 2i+1 low nibble
                by = p[8*(j/2) +: 8];
                o[4*j +: 4] = (j % 2 == 0) ? by[7:4] : by[3:0];
            end else if (shift_load) begin
                // EGA E19: even map bytes on even characters, odd on odd,
                // on the even colour outputs
                for (int c = 0; c < 2; c++) begin
                    by = odd ? p[8*(2*c+1) +: 8] : p[8*(2*c) +: 8];
                    o[4*j + 2*c] = by[7-j];
                end
            end else if (regs[5][5]) begin
                for (int c = 0; c < 2; c++) begin
                    by = (j < 4) ? p[8*(2*c) +: 8] : p[8*(2*c+1) +: 8];
                    o[4*j + 2*c + 1] = by[7 - 2*(j & 3)];
                    o[4*j + 2*c]     = by[6 - 2*(j & 3)];
                end
            end else begin
                for (int n = 0; n < 4; n++) o[4*j + n] = p[8*n + 7 - j];
            end
        end
        ser = o;                       // EGA E32: the 9th dot is 0
    endfunction

    assign e_ser = ser(e_p, e_odd);
    assign n_ser = ser(n_p, n_odd);
`ifdef FORMAL
    // Formal checks (formal/vga_graphics_ctrl.sby): the write-mode
    // equations of p.2-79 to 2-88 on one anyconst bit slice and map,
    // written with index arithmetic independently of the shift expressions
    // above; both read modes; stored register widths.
    (* anyconst *) logic [2:0] f_b;
    (* anyconst *) logic [1:0] f_n;
    logic f_init = 1'b1;
    always_ff @(posedge clk) f_init <= 1'b0;
    always_comb if (f_init) assume (!rst_n);

    logic f_src, f_alu, f_mask, f_l, f_exp;
    always_comb begin
        f_l = lat[8*f_n + f_b];
        unique case (regs[5][1:0])
            2'd0: f_src = regs[1][f_n] ? regs[0][f_n] : cpu_d[3'(f_b + regs[3][2:0])];
            2'd2: f_src = cpu_d[f_n];
            2'd3: f_src = regs[0][f_n];
            default: f_src = f_l;
        endcase
        unique case (regs[3][4:3])
            2'd0: f_alu = f_src;
            2'd1: f_alu = f_src & f_l;
            2'd2: f_alu = f_src | f_l;
            2'd3: f_alu = f_src ^ f_l;
        endcase
        f_mask = regs[8][f_b] && (regs[5][1:0] != 2'd3 || cpu_d[3'(f_b + regs[3][2:0])]);
        f_exp = (regs[5][1:0] == 2'd1) ? f_l : (f_mask ? f_alu : f_l);
    end

    always_comb begin
        if (rst_n) begin
            assert (wd[8*f_n + f_b] == f_exp);
            if (regs[5][3]) begin
                assert (rd_data[f_b] == (
                    (!regs[7][0] || rd[f_b] == regs[2][0]) && (!regs[7][1] || rd[8 + f_b] == regs[2][1]) &&
                    (!regs[7][2] || rd[16 + f_b] == regs[2][2]) && (!regs[7][3] || rd[24 + f_b] == regs[2][3])));
            end else if (chain4) begin
                assert (rd_data == rd[8*chain4_map +: 8]);
            end else begin
                assert (rd_data == rd[8*(regs[5][4] ? {regs[4][1], a0} : regs[4][1:0]) +: 8]);
            end
            assert (regs[0][7:4] == 4'd0 && regs[1][7:4] == 4'd0 && regs[2][7:4] == 4'd0);
            assert (regs[3][7:5] == 3'd0 && regs[4][7:2] == 6'd0 && regs[5][7] == 1'b0 &&
                    regs[5][2] == 1'b0);
            assert (regs[6][7:4] == 4'd0 && regs[7][7:4] == 4'd0);
        end
    end

    always_comb begin
        if (rst_n) begin
            cover (regs[5][1:0] == 2'd0 && regs[1][0] && regs[3][2:0] != 3'd0);
            cover (regs[5][1:0] == 2'd1);
            cover (regs[5][1:0] == 2'd2 && regs[3][4:3] == 2'd3);
            cover (regs[5][1:0] == 2'd3 && regs[8] == 8'h0F);
            cover (regs[5][3] && regs[7][3:0] == 4'hF && rd_data == 8'hA5);
            cover (regs[5][6]);
        end
    end
`endif
endmodule
