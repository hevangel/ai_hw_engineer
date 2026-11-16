// IBM VGA display fetch and character pipeline (VGAXGA p.2-15, p.2-101;
// copied from ega_display_fetch.sv).
//
// At each character boundary the four map bytes are read at the CRTC
// address; in alphanumeric modes (Graphics Miscellaneous bit 0 = 0) map 2
// is then read again at the character generator address {table, character
// code, row scan} (ASSUMPTION V12). The fetched character enters a
// three-deep history: at boundary k (before it is processed) n = fetched at
// k-1, e = k-2, e2 = k-3. The CRTC flags of each boundary enter a 7-deep
// history (index d = boundary k-d). The top selects the depths
// (ASSUMPTION V14).
module vga_display_fetch (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        char_ce,
    input  logic        f_de,
    input  logic        f_blank,
    input  logic        f_hs,
    input  logic        f_cursor,
    input  logic        f_ul,
    input  logic        f_hcodd,
    input  logic [15:0] crtc_addr,
    input  logic [4:0]  rs,
    input  logic        ext_mem,
    input  logic        gc_graphics,
    input  logic [2:0]  font_tbl,       // character table, map 2 address bits 15-13
    output logic        fattr_b3,
    output logic [15:0] b_addr,
    input  logic [31:0] b_rdata,
    output logic [7:1]  h_de,
    output logic [7:1]  h_blank,
    output logic [7:1]  h_hs,
    output logic [7:1]  h_cursor,
    output logic [31:0] n_p, e_p, e2_p,
    output logic [7:0]  n_font, e_font, e2_font,
    output logic        n_gcg, e_gcg, e2_gcg,
    output logic        n_odd, e_odd, e2_odd,
    output logic        n_ul, e_ul, e2_ul
);
    logic [1:0]  st;          // 0 idle, 1 planes arriving, 2 font arriving
    logic [4:0]  rs_f;
    logic [15:0] font_addr;

    always_comb begin
        font_addr = {font_tbl, b_rdata[7:0], rs_f};
        if (!ext_mem) font_addr[15:14] = 2'b00;
    end
    assign fattr_b3 = b_rdata[11];

    always_comb begin
        if (st == 2'd1) b_addr = font_addr;
        else            b_addr = ext_mem ? crtc_addr : {2'b00, crtc_addr[13:0]};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            st <= 2'd0;
            rs_f <= 5'd0;
            h_de <= '0; h_blank <= '0; h_hs <= '0; h_cursor <= '0;
            n_p <= '0; e_p <= '0; e2_p <= '0;
            n_font <= '0; e_font <= '0; e2_font <= '0;
            n_gcg <= 1'b0; e_gcg <= 1'b0; e2_gcg <= 1'b0;
            n_odd <= 1'b0; e_odd <= 1'b0; e2_odd <= 1'b0;
            n_ul <= 1'b0; e_ul <= 1'b0; e2_ul <= 1'b0;
        end else begin
            if (char_ce) begin
                h_de     <= {h_de[6:1], f_de};
                h_blank  <= {h_blank[6:1], f_blank};
                h_hs     <= {h_hs[6:1], f_hs};
                h_cursor <= {h_cursor[6:1], f_cursor};
                e2_p <= e_p; e2_font <= e_font; e2_gcg <= e_gcg; e2_odd <= e_odd; e2_ul <= e_ul;
                e_p <= n_p; e_font <= n_font; e_gcg <= n_gcg; e_odd <= n_odd; e_ul <= n_ul;
                n_gcg <= gc_graphics;
                n_odd <= f_hcodd;
                n_ul  <= f_ul;
                rs_f  <= rs;
                st    <= 2'd1;
            end else if (st == 2'd1) begin
                n_p <= b_rdata;
                st <= n_gcg ? 2'd0 : 2'd2;
                if (n_gcg) n_font <= b_rdata[23:16];
            end else if (st == 2'd2) begin
                n_font <= b_rdata[23:16];
                st <= 2'd0;
            end
        end
    end
endmodule
