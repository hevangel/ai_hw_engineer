// IBM EGA display fetch and character pipeline (TR p.8, p.69; sheets 3, 5).
//
// At each character boundary the four plane bytes are read at the CRTC
// address; in alphanumeric modes (Graphics Miscellaneous bit 0 = 0) the
// character-generator address latches then redirect plane 2 to
// {map, 0, character code, row scan} (TR p.69-70). The fetched character
// and the CRTC flags of that boundary enter a short history; the attribute
// controller displays history entry k-2 (ASSUMPTION E18).
//
// History index h: entry for boundary k-6+h after a boundary has been
// processed, i.e. h5 = most recent fetch (k-1 when the next boundary uses
// it), h4 = k-2, ...
module ega_display_fetch (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        char_ce,
    // CRTC current-character flags
    input  logic        f_de,
    input  logic        f_blank,
    input  logic        f_hs,
    input  logic        f_cursor,
    input  logic        f_ul,
    input  logic        f_hcodd,
    input  logic [15:0] crtc_addr,
    input  logic [4:0]  rs,
    input  logic        ext_mem,        // Memory Mode bit 1
    input  logic        gc_graphics,    // Graphics Miscellaneous bit 0
    input  logic [1:0]  font_map,       // from the sequencer (uses fattr_b3)
    output logic        fattr_b3,       // attribute bit 3 of the fetched char
    // display read port of the four planes
    output logic [15:0] b_addr,
    input  logic [31:0] b_rdata,        // plane 3..0
    // history (index 1 oldest .. 5 newest)
    output logic [5:2]  h_de,           // display enable needs k-1..k-4
    output logic        h_blank,        // blank needs k-1
    output logic [5:3]  h_hs,           // horizontal retrace needs k-1..k-3
    output logic [5:1]  h_cursor,       // cursor needs k-2..k-5 (E), k-1.. (N)
    output logic [31:0] e_planes, n_planes,
    output logic [7:0]  e_font, n_font,
    output logic        e_gcg, n_gcg,
    output logic        e_odd, n_odd,
    output logic        e_ul, n_ul
);
    logic [1:0]  st;          // 0 idle, 1 planes arriving, 2 font arriving
    logic [4:0]  rs_f;
    logic [15:0] font_addr;

    always_comb begin
        font_addr = {font_map, 1'b0, b_rdata[7:0], rs_f};
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
            h_de <= '0; h_blank <= 1'b0; h_hs <= '0; h_cursor <= '0;
            e_planes <= '0; n_planes <= '0; e_font <= '0; n_font <= '0;
            e_gcg <= 1'b0; n_gcg <= 1'b0; e_odd <= 1'b0; n_odd <= 1'b0;
            e_ul <= 1'b0; n_ul <= 1'b0;
        end else begin
            if (char_ce) begin
                h_de     <= {f_de, h_de[5:3]};
                h_blank  <= f_blank;
                h_hs     <= {f_hs, h_hs[5:4]};
                h_cursor <= {f_cursor, h_cursor[5:2]};
                e_planes <= n_planes; e_font <= n_font; e_gcg <= n_gcg;
                e_odd <= n_odd; e_ul <= n_ul;
                n_gcg <= gc_graphics;
                n_odd <= f_hcodd;
                n_ul  <= f_ul;
                rs_f  <= rs;
                st    <= 2'd1;
            end else if (st == 2'd1) begin
                n_planes <= b_rdata;
                st <= n_gcg ? 2'd0 : 2'd2;
                if (n_gcg) n_font <= b_rdata[23:16];
            end else if (st == 2'd2) begin
                n_font <= b_rdata[23:16];
                st <= 2'd0;
            end
        end
    end
endmodule
