// IBM EGA graphics controller LSI (TR p.45-55, sheets 6/7). The card has
// two: GC 1 serves planes 0/1, GC 2 planes 2/3. Both receive every write to
// 3CE/3CF; the Position register (3CC for GC 1, 3CA for GC 2) tells a chip
// which two bits of the 4-bit plane fields belong to it (bit index
// n = 2 x position + plane-in-chip).
//
// Per chip: Set/Reset, Enable Set/Reset, Color Compare, Data Rotate and
// Function Select, Read Map Select, Mode (write mode 0-2, test condition,
// read mode, odd/even, shift register), Miscellaneous (graphics, chain,
// memory map), Color Don't Care, Bit Mask; the two processor latches; the
// write path; the read path; and the serializer of its two planes.
module ega_graphics_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        addr_we,
    input  logic        data_we,
    input  logic        pos_we,
    input  logic [7:0]  wdata,
    // processor write data for this chip's planes
    input  logic [7:0]  cpu_d,
    output logic [7:0]  wd0,
    output logic [7:0]  wd1,
    output logic        wr_valid,      // 0 in write mode 3 (ASSUMPTION E29)
    // processor read
    input  logic [7:0]  rd0,
    input  logic [7:0]  rd1,
    input  logic        a0,
    input  logic        latch_we,
    output logic        rd_drive,
    output logic [7:0]  rd_data,
    // serializer: this chip's two planes for two fetched characters
    input  logic        shift_load,
    input  logic [7:0]  e_p0, e_p1,
    input  logic        e_odd,
    input  logic [7:0]  n_p0, n_p1,
    input  logic        n_odd,
    output logic [17:0] e_ser,         // dot j: e_ser[2j+1:2j] = {C(2i+1), C(2i)}
    output logic [17:0] n_ser,
    // register views
    output logic [71:0] dbg_regs,      // register 8..0, 8 bits each
    output logic [3:0]  idx,
    output logic [1:0]  pos,
    output logic [7:0]  lat0,
    output logic [7:0]  lat1
);
    logic [7:0] regs [0:8];
    logic [7:0] wmask;

    always_comb begin
        unique case (idx)
            4'd3:    wmask = 8'h1F;
            4'd4:    wmask = 8'h07;
            4'd5:    wmask = 8'h3F;
            4'd8:    wmask = 8'hFF;
            default: wmask = 8'h0F;
        endcase
    end

    assign dbg_regs = {regs[8], regs[7], regs[6], regs[5], regs[4], regs[3],
                       regs[2], regs[1], regs[0]};

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 4'd0;
            pos <= 2'd0;
            for (int i = 0; i < 9; i++) regs[i] <= 8'h00;
        end else begin
            if (addr_we) idx <= wdata[3:0];
            if (data_we && idx <= 4'd8) regs[idx] <= wdata & wmask;
            if (pos_we) pos <= wdata[1:0];
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lat0 <= 8'h00;
            lat1 <= 8'h00;
        end else if (latch_we) begin
            lat0 <= rd0;
            lat1 <= rd1;
        end
    end

    // bit n of a 4-bit plane field for plane q of this chip
    function automatic logic fbit(input logic [7:0] r, input logic [1:0] p, input logic q);
        logic [2:0] n;
        n = {p, q};
        fbit = !n[2] && r[{1'b0, n[1:0]}];
    endfunction

    // ------------------------------------------------------ write path
    logic [7:0] rot;
    logic [1:0] wm, fn;
    assign wm  = regs[5][1:0];
    assign fn  = regs[3][4:3];
    assign wr_valid = (wm != 2'd3);
    // ASSUMPTION E33: rotate right (VGA p.2-82)
    assign rot = (cpu_d >> regs[3][2:0]) | (cpu_d << (4'd8 - {1'b0, regs[3][2:0]}));

    function automatic logic [7:0] wpath(input logic q, input logic [7:0] lat);
        logic [7:0] v;
        logic [2:0] n;
        n = {pos, q};
        if (wm == 2'd2) v = {8{cpu_d[n]}};
        else if (fbit(regs[1], pos, q)) v = {8{fbit(regs[0], pos, q)}};
        else v = rot;
        unique case (fn)
            2'd0: ;
            2'd1: v = v & lat;
            2'd2: v = v | lat;
            2'd3: v = v ^ lat;
        endcase
        v = (v & regs[8]) | (lat & ~regs[8]);
        wpath = (wm == 2'd1) ? lat : v;
    endfunction

    assign wd0 = wpath(1'b0, lat0);
    assign wd1 = wpath(1'b1, lat1);

    // ------------------------------------------------------- read path
    logic [2:0] plane;
    logic [7:0] cmp0, cmp1;
    always_comb begin
        plane = regs[5][4] ? {regs[4][2:1], a0} : regs[4][2:0];
        // ASSUMPTION E15: Color Don't Care bit 1 = the plane is compared
        cmp0 = fbit(regs[7], pos, 1'b0) ? ~(rd0 ^ {8{fbit(regs[2], pos, 1'b0)}}) : 8'hFF;
        cmp1 = fbit(regs[7], pos, 1'b1) ? ~(rd1 ^ {8{fbit(regs[2], pos, 1'b1)}}) : 8'hFF;
        if (regs[5][3]) begin
            rd_drive = 1'b1;
            rd_data  = cmp0 & cmp1;
        end else begin
            rd_drive = (plane[2:1] == pos);
            rd_data  = plane[0] ? rd1 : rd0;
        end
    end

    // ------------------------------------------------------ serializer
    function automatic logic [17:0] ser(input logic [7:0] p0, input logic [7:0] p1,
                                        input logic odd);
        logic [17:0] o;
        logic [7:0]  by;
        o = 18'd0;
        for (int j = 0; j < 8; j++) begin
            if (shift_load) begin
                // ASSUMPTION E19
                by = odd ? p1 : p0;
                o[2*j] = by[7-j];
            end else if (regs[5][5]) begin
                by = (j < 4) ? p0 : p1;
                o[2*j+1] = by[7 - 2*(j & 3)];
                o[2*j]   = by[6 - 2*(j & 3)];
            end else begin
                o[2*j]   = p0[7-j];
                o[2*j+1] = p1[7-j];
            end
        end
        ser = o;                   // ASSUMPTION E32: dot 8 is 0
    endfunction

    assign e_ser = ser(e_p0, e_p1, e_odd);
    assign n_ser = ser(n_p0, n_p1, n_odd);
endmodule
