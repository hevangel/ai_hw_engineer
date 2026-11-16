// IBM VGA video DAC (Inmos IMS G171 compatible): 256 x 18-bit palette,
// PEL mask, address/data state machine, DAC state, RGB outputs and the
// switch-sense comparator (VGAXGA p.2-104 to 2-106, HITR p.90-93).
//
// The DAC samples the 8-bit address from the attribute controller on each
// dot clock; the outputs hold that dot's 6-bit R, G, B (0 while blanked).
// ASSUMPTION V23: the 3-PEL-clock pipeline of the real DAC is not modeled.
module vga_dac #(
    parameter int SENSE_REF = 26     // ASSUMPTION V21 (DAC code units)
) (
    input  logic        clk,
    input  logic        rst_n,
    // processor (events at strobe release)
    input  logic        pelmask_we,  // 3C6 write
    input  logic        ra_we,       // 3C7 write
    input  logic        wa_we,       // 3C8 write
    input  logic        data_we,     // 3C9 write
    input  logic        data_re,     // 3C9 read
    input  logic [7:0]  wdata,
    output logic [7:0]  rd_data,     // 3C9 read value
    output logic [7:0]  rd_addr,     // 3C8 read value
    output logic [7:0]  rd_state,    // 3C7 read value
    output logic [7:0]  pelmask,
    // display
    input  logic        dot_ce,
    input  logic [7:0]  pix_addr,
    input  logic        pix_blank,
    input  logic [2:0]  load,        // R, G, B terminated by the display
    output logic [5:0]  r,
    output logic [5:0]  g,
    output logic [5:0]  b,
    output logic        sense,
    // debug / state views
    input  logic [7:0]  dbg_addr,
    output logic [17:0] dbg_rgb,
    output logic [7:0]  addr,
    output logic [1:0]  sub,
    output logic        rmode,
    output logic [5:0]  hold_r,
    output logic [5:0]  hold_g
);
    logic [17:0] cpu_q, pix_q;
    logic        f_wr;                 // completing write strobe
    logic [17:0] f_wval;
    assign f_wr   = data_we && (sub == 2'd2);
    assign f_wval = {hold_r, hold_g, wdata[5:0]};

`ifdef FORMAL
    // Formal (formal/vga_dac.sby): the palette is one shadow entry at an
    // anyconst address; every other entry reads unconstrained data.
    (* anyconst *) logic [7:0] f_ea;
    (* anyseq *)   logic [17:0] f_any_c, f_any_p, f_any_d;
    logic [17:0] f_entry;
    always_ff @(posedge clk) begin
        if (!rst_n)                      f_entry <= 18'd0;
        else if (f_wr && addr == f_ea)   f_entry <= f_wval;
    end
    assign cpu_q   = (addr == f_ea) ? f_entry : f_any_c;
    assign pix_q   = ((pix_addr & pelmask) == f_ea) ? f_entry : f_any_p;
    assign dbg_rgb = (dbg_addr == f_ea) ? f_entry : f_any_d;
`else
    logic [17:0] mem [0:255];
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 256; i++) mem[i] <= 18'd0;      // ASSUMPTION V1
        end else if (f_wr) begin
            mem[addr] <= f_wval;
        end
    end
    assign cpu_q   = mem[addr];
    assign pix_q   = mem[pix_addr & pelmask];                  // ASSUMPTION V19
    assign dbg_rgb = mem[dbg_addr];
`endif

    // ASSUMPTION V20: one address register, one shared sub-index
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr <= 8'd0; sub <= 2'd0; rmode <= 1'b0;
            hold_r <= 6'd0; hold_g <= 6'd0; pelmask <= 8'h00;
        end else begin
            if (pelmask_we) pelmask <= wdata;
            if (wa_we) begin
                addr <= wdata; sub <= 2'd0; rmode <= 1'b0;
            end else if (ra_we) begin
                addr <= wdata; sub <= 2'd0; rmode <= 1'b1;
            end else if (data_we || data_re) begin
                if (data_we && sub == 2'd0) hold_r <= wdata[5:0];
                if (data_we && sub == 2'd1) hold_g <= wdata[5:0];
                if (sub == 2'd2) begin
                    sub  <= 2'd0;
                    addr <= addr + 8'd1;
                end else begin
                    sub <= sub + 2'd1;
                end
            end
        end
    end

    always_comb begin
        unique case (sub)
            2'd0:    rd_data = {2'b00, cpu_q[17:12]};
            2'd1:    rd_data = {2'b00, cpu_q[11:6]};
            default: rd_data = {2'b00, cpu_q[5:0]};
        endcase
    end
    assign rd_addr  = addr;
    assign rd_state = rmode ? 8'h03 : 8'h00;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            r <= 6'd0; g <= 6'd0; b <= 6'd0;
        end else if (dot_ce) begin
            r <= pix_blank ? 6'd0 : pix_q[17:12];
            g <= pix_blank ? 6'd0 : pix_q[11:6];
            b <= pix_blank ? 6'd0 : pix_q[5:0];
        end
    end

    // ASSUMPTION V21: switch sense = every output below the reference; an
    // output without a load is at twice the voltage of a terminated one.
    function automatic logic below(input logic [5:0] v, input logic ld);
        logic [6:0] e;
        e = ld ? {1'b0, v} : {v, 1'b0};
        below = (e < 7'(SENSE_REF));
    endfunction
    assign sense = below(r, load[2]) && below(g, load[1]) && below(b, load[0]);
`ifdef FORMAL
    logic f_init = 1'b1;
    always_ff @(posedge clk) f_init <= 1'b0;
    always_comb begin
        if (f_init) assume (!rst_n);
        assume ($onehot0({pelmask_we, ra_we, wa_we, data_we, data_re}));
    end
    always_comb begin
        if (rst_n && !f_init) begin
            assert (sub != 2'd3);
            assert (rd_state == (rmode ? 8'h03 : 8'h00));
            assert (rd_data[7:6] == 2'b00);
        end
    end
    always_ff @(posedge clk) begin
        if ($past(rst_n) && rst_n && !f_init && !$past(f_init)) begin
            // address loads reset the sub-index and select the direction
            if ($past(wa_we)) assert (addr == $past(wdata) && sub == 2'd0 && !rmode);
            else if ($past(ra_we)) assert (addr == $past(wdata) && sub == 2'd0 && rmode);
            // a data access advances the sub-index; the third the address
            else if ($past(data_we || data_re)) begin
                if ($past(sub) == 2'd2) assert (sub == 2'd0 && addr == $past(addr) + 8'd1);
                else                    assert (sub == $past(sub) + 2'd1 && addr == $past(addr));
                assert (rmode == $past(rmode));
            end else begin
                assert (sub == $past(sub) && addr == $past(addr) && rmode == $past(rmode));
            end
            // the shadow entry holds the last completed triple written to it
            if ($past(f_wr && addr == f_ea))
                assert (f_entry == $past(f_wval));
            else
                assert (f_entry == $past(f_entry));
            // a read of the entry returns R, G, B in that order
            if (addr == f_ea && sub == 2'd0) assert (rd_data == {2'b00, f_entry[17:12]});
            if (addr == f_ea && sub == 2'd1) assert (rd_data == {2'b00, f_entry[11:6]});
            if (addr == f_ea && sub == 2'd2) assert (rd_data == {2'b00, f_entry[5:0]});
            // blanked dots are black
            if ($past(dot_ce && pix_blank)) assert (r == 6'd0 && g == 6'd0 && b == 6'd0);
`ifdef FORMAL_COVER
            cover (f_entry == 18'h3F03F && addr == f_ea + 8'd1);
            cover (rmode && sub == 2'd2 && addr == f_ea);
            cover (sense && load == 3'b111 && $past(dot_ce) && !$past(pix_blank));
`endif
        end
    end
`endif
endmodule
