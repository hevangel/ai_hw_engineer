// IBM EGA external registers (TR p.12-17, sheets 2 and 9): Miscellaneous
// Output (LS273 U37), Feature Control (LS175 U49), the Input Status 0 bits
// from LS367 U35, the switch-sense multiplexer and the dot-clock source
// multiplexer (LS153 U15), and the light-pen flip-flop (74LS74 U18).
module ega_ext_regs (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       reset_drv,     // slot RESET DRV: U37/U49 CLR
    // processor writes (events)
    input  logic       misc_we,
    input  logic       fcr_we,
    input  logic       lpclr_we,
    input  logic       lpset_we,
    input  logic [7:0] wdata,
    // board inputs
    input  logic [3:0] sw,            // sw[n] = SW(n+1); 1 = open
    input  logic [1:0] feat,
    input  logic       lpen_n,        // P2-1 -LPEN IN (sampled)
    input  logic       osc14_ce,
    input  logic       osc16_ce,
    input  logic       ext_osc_ce,
    input  logic       vint,          // vertical interrupt latch (CRTC)
    output logic [7:0] misc,
    output logic [1:0] fcr,
    output logic       lpff,
    output logic       master_ce,     // selected dot-clock source pulse
    output logic [7:0] isr0
);
    logic lpen_q;
    logic sw_sense;

    always_ff @(posedge clk) begin
        if (!rst_n || reset_drv) begin
            misc <= 8'h00;
            fcr  <= 2'b00;
        end else begin
            if (misc_we) misc <= wdata;
            if (fcr_we)  fcr  <= wdata[1:0];
        end
    end

    // U18: PR = LP SET, CLR = LP CLR, clocked by the inverted -LPEN IN, so a
    // falling edge of the pin sets Q.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lpff   <= 1'b0;
            lpen_q <= 1'b1;
        end else begin
            lpen_q <= lpen_n;
            if (lpclr_we)                 lpff <= 1'b0;
            else if (lpset_we)            lpff <= 1'b1;
            else if (lpen_q && !lpen_n)   lpff <= 1'b1;
        end
    end

    // U15 1C0..1C3 = 14 MHz, 16 MHz, EXT OSC, not connected.
    always_comb begin
        unique case (misc[3:2])
            2'b00: master_ce = osc14_ce;
            2'b01: master_ce = osc16_ce;
            2'b10: master_ce = ext_osc_ce;
            2'b11: master_ce = 1'b0;
        endcase
    end

    // ASSUMPTION E31: clock select k reads switch SW(4-k) (BIOS POST
    // C000:009B builds INFO_3 bit 3 from select 00; TR p.15 bit 3 = SW4).
    always_comb begin
        unique case (misc[3:2])
            2'b00: sw_sense = sw[3];
            2'b01: sw_sense = sw[2];
            2'b10: sw_sense = sw[1];
            2'b11: sw_sense = sw[0];
        endcase
    end

    // ASSUMPTION E4: bits 3-0 are not driven (BD bus pull-ups, U38).
    // ASSUMPTION E9: bit 7 = CRTINT = vertical interrupt latch.
    assign isr0 = {vint, feat, sw_sense, 4'hF};
endmodule
