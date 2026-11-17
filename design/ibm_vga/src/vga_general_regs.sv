// IBM PS/2 Display Adapter general and card registers: Miscellaneous
// Output (W 3C2, R 3CC), Feature Control (W 3xA, R 3CA), Input Status 0
// (3C2), the video setup/enable register 46E8h, POS register 102h and the
// dot-clock source multiplexer (VGAXGA p.2-42 to 2-46, HITR p.10/38-41).
module vga_general_regs (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       reset_drv,     // slot RESET DRV (ASSUMPTION V2)
    input  logic       misc_we,
    input  logic       fcr_we,
    input  logic       vse_we,        // 46E8h
    input  logic       pos_we,        // 102h (setup only, decoded outside)
    input  logic [7:0] wdata,
    input  logic       osc25_ce,
    input  logic       osc28_ce,
    input  logic       ext_osc_ce,
    input  logic       vint,          // vertical interrupt latch (CRTC)
    input  logic       sense,         // DAC switch-sense comparator
    output logic [7:0] misc,
    output logic [7:0] fcr,
    output logic [7:0] vse,
    output logic       pos,
    output logic       enable,
    output logic       setup,
    output logic       master_ce,
    output logic [7:0] isr0
);
    always_ff @(posedge clk) begin
        if (!rst_n || reset_drv) begin
            misc <= 8'h00;
            vse  <= 8'h00;
            pos  <= 1'b0;
            if (!rst_n) fcr <= 8'h00;
        end else begin
            if (misc_we) misc <= wdata;
            if (fcr_we)  fcr  <= wdata;
            if (vse_we)  vse  <= wdata;
            if (pos_we)  pos  <= wdata[0];
        end
    end

    // ASSUMPTION V4: enable = 46E8h bit 3 AND POS 102h bit 0
    assign enable = vse[3] && pos;
    assign setup  = vse[4];

    always_comb begin
        unique case (misc[3:2])
            2'b00: master_ce = osc25_ce;
            2'b01: master_ce = osc28_ce;
            2'b10: master_ce = ext_osc_ce;
            2'b11: master_ce = 1'b0;          // reserved
        endcase
    end

    // ASSUMPTION V7: undefined bits read 0; V21: bit 4 = switch sense
    assign isr0 = {vint, 2'b00, sense, 4'h0};
endmodule
