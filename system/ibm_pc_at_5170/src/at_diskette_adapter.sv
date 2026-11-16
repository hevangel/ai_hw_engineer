// Diskette function of the IBM Personal Computer AT Fixed Disk and Diskette
// Drive Adapter, as an 8-bit I/O channel card.
//
// Source: IBM PC AT Technical Reference 1502494 (March 1984), section
// "Fixed Disk and Diskette Adapter": Digital Output Register at 3F2h (PDF
// page 611), Digital Input Register and data rates (PDF 611-612), the NEC
// uPD765 / Intel 8272 controller at 3F4h (main status) and 3F5h (data)
// (PDF 612-613), the I/O map with 3F7h read = digital input register and
// 3F7h write = diskette control register, and "DMA request is level 2 and
// interrupt request is level 6" (PDF 628), and the diskette drive cable,
// which carries Diskette Change on pin 34 and no Ready line (PDF 633). The
// data-rate encoding 00 = 500, 01 = 300, 10 = 250 kbit/s is the BIOS's
// (DSKETTE listing, PDF 228, "DATA TRANSFER RATE FOR THIS DRIVE"; it writes
// it to 3F7h).
//
// Only the diskette function is modeled. The fixed-disk function (task file
// 1F0h-1F7h, fixed disk register 3F6h, IRQ 14) is absent: none of its ports
// is decoded, so on this machine they read as an empty slot.
//
// The adapter's logic diagrams (PDF 635-642) were not traced; every gate
// level detail below that the prose does not state is an assumption with a
// number in the specification's ledger.
//
// The controller is design/intel_8272 with its decoded-media interface
// brought out to the drives (the host's media backend,
// tb/at_diskette_media.hpp).
module at_diskette_adapter #(
    // Processor clocks per second on the virtual time base the drives and
    // the controller's microsecond timers use (ASSUMPTION AT27).
    parameter int unsigned CLK_HZ = 6_000_000,
    parameter integer RQM_DELAY_US = 12,
    parameter integer MS_US = 1000
) (
    input  logic        clk_i,
    input  logic        reset_drv_i,
    // I/O channel slot.
    input  logic [19:0] a_i,
    input  logic [7:0]  d_i,
    output logic [7:0]  d_o,
    output logic        d_oe_o,
    input  logic        ior_n_i, iow_n_i, aen_i,
    output logic        drq2_o,
    input  logic        dack2_n_i,
    input  logic        tc_i,
    output logic        irq6_o,
    // Drive cable (two drives). drive_select_o is one-hot: drive A, drive B.
    output logic [1:0]  drive_select_o,
    output logic [1:0]  motor_on_o,
    output logic        step_o, direction_o, head_o,
    output logic [1:0]  data_rate_o,     // 00 = 500, 01 = 300, 10 = 250 kbit/s
    input  logic        track0_i, write_protect_i, disk_change_i,  // selected drive
    // Decoded media (design/intel_8272/docs/media_interface.md).
    output logic        media_active_o, media_write_o, media_format_o, mfm_o,
    input  logic        index_i, header_valid_i,
    input  logic [7:0]  header_c_i, header_h_i, header_r_i, header_n_i,
    input  logic        media_byte_valid_i,
    input  logic [7:0]  media_byte_i,
    input  logic        media_end_i, write_slot_i,
    output logic        sector_begin_o, sector_end_o, tx_valid_o,
    output logic [7:0]  tx_byte_o, sector_r_o
);
    // ASSUMPTION AT28 (see spec): the adapter decodes SA0-SA9 with AEN low,
    // so its ports alias every 400h; the I/O channel description allows
    // adapters at 100h-3FFh.
    logic sel_dor, sel_fdc, sel_dir;
    assign sel_dor = !aen_i && a_i[9:0] == 10'h3f2;
    assign sel_fdc = !aen_i && a_i[9:1] == 9'h1fa;          // 3F4h, 3F5h
    assign sel_dir = !aen_i && a_i[9:0] == 10'h3f7;

    // Digital output register (PDF 611): bit 0 drive select (0 = A),
    // bit 1 reserved, bit 2 -diskette function reset, bit 3 enable diskette
    // interrupts and DMA, bits 4/5 drive A/B motor enable. A channel reset
    // (RESET DRV) clears all bits. The diskette control register at 3F7h
    // (write) holds the data rate in bits 1-0.
    // ASSUMPTION AT29 (see spec): RESET DRV also clears the data rate
    // (500 kbit/s); bits 7-2 of the 3F7h write are ignored.
    logic [7:0] dor;
    logic [1:0] rate;
    logic iow_q, ior_q;
    always_ff @(posedge clk_i) begin
        iow_q <= iow_n_i;
        ior_q <= ior_n_i;
        if (reset_drv_i) begin
            dor <= 8'h00;
            rate <= 2'b00;
        end else if (iow_q && !iow_n_i) begin
            if (sel_dor) dor <= d_i;
            if (sel_dir) rate <= d_i[1:0];
        end
    end
    assign data_rate_o = rate;
    assign motor_on_o = dor[5:4];
    // ASSUMPTION AT30 (see spec): a drive's select line on the cable is
    // active when the DOR selects it and its motor enable bit is set, as on
    // the IBM PC diskette adapter; the AT BIOS always sets both together.
    assign drive_select_o = {dor[0] && dor[5], !dor[0] && dor[4]};

    // Microsecond tick for the controller's timers.
    logic [$clog2(CLK_HZ)-1:0] us_phase;
    logic us_tick;
    always_ff @(posedge clk_i) begin
        if (reset_drv_i) begin
            us_phase <= '0;
            us_tick <= 1'b0;
        end else if (32'(us_phase) + 1_000_000 >= CLK_HZ) begin
            us_phase <= $bits(us_phase)'(32'(us_phase) + 1_000_000 - CLK_HZ);
            us_tick <= 1'b1;
        end else begin
            us_phase <= $bits(us_phase)'(32'(us_phase) + 1_000_000);
            us_tick <= 1'b0;
        end
    end

    // The controller. Its reset is RESET DRV or DOR bit 2 low (PDF 611,
    // "Diskette Function Reset").
    // ASSUMPTION AT31 (see spec): the cable has no Ready line (PDF 633), so
    // the controller's READY input is taken as always active, as on the IBM
    // PC adapter; the two-side and fault inputs are inactive. The drive
    // cable selects one drive (DOR bit 0), so that drive's track 0 and
    // write-protect lines reach the controller for every unit number, and
    // any unit's step pulse steps the selected drive.
    // ASSUMPTION AT32 (see spec): DRQ2 and IRQ6 are the controller's DRQ and
    // INT gated by DOR bit 3 ("Enable Diskette Interrupts and DMA"); a gated
    // line is inactive (low). The controller's TC is the channel's T/C while
    // -DACK2 is active.
    // ASSUMPTION AT27 (see spec): the controller's timers run at the 8 MHz
    // controller-clock values of the Intel data sheet (CLOCK_SCALE 1) at all
    // three data rates; the Technical Reference (PDF 615) doubles HLT/HUT
    // and SRT units for the 250 kbit/s drive, which is not modeled.
    logic [7:0] fdc_d;
    logic fdc_oe, fdc_irq, fdc_drq, fdc_head, fdc_load, fdc_deleted;
    logic [3:0] fdc_step, fdc_dir;
    logic [1:0] fdc_unit;
    logic [7:0] sec_c, sec_h, sec_n;
    intel_8272 #(.RQM_DELAY_US(RQM_DELAY_US), .MS_US(MS_US), .CLOCK_SCALE(1)) fdc (
        .clk(clk_i), .rst_n(!reset_drv_i && dor[2]), .us_tick(us_tick),
        .cs_n(!sel_fdc), .rd_n(ior_n_i), .wr_n(iow_n_i), .dack_n(dack2_n_i), .a0(a_i[0]),
        .tc(tc_i && !dack2_n_i), .db_in(d_i), .db_out(fdc_d), .db_oe(fdc_oe),
        .irq(fdc_irq), .drq(fdc_drq),
        .ready(4'b1111), .write_protect({4{write_protect_i}}), .track0({4{track0_i}}),
        .two_sided(4'b0000), .fault(4'b0000), .step(fdc_step), .direction(fdc_dir),
        .unit(fdc_unit), .head(fdc_head), .mfm(mfm_o), .head_load(fdc_load),
        .media_active(media_active_o), .media_write(media_write_o), .media_format(media_format_o),
        .index_pulse(index_i), .header_valid(header_valid_i), .header_c(header_c_i),
        .header_h(header_h_i), .header_r(header_r_i), .header_n(header_n_i),
        .header_deleted(1'b0), .header_missing_data(1'b0), .header_crc_error(1'b0),
        .media_byte_valid(media_byte_valid_i), .media_byte(media_byte_i),
        .media_end(media_end_i), .media_crc_error(1'b0), .write_slot(write_slot_i),
        .sector_begin(sector_begin_o), .sector_end(sector_end_o), .tx_valid(tx_valid_o),
        .tx_byte(tx_byte_o), .sector_c(sec_c), .sector_h(sec_h), .sector_r(sector_r_o),
        .sector_n(sec_n), .sector_deleted(fdc_deleted)
    );
    assign step_o = |fdc_step;
    assign direction_o = |(fdc_step & fdc_dir);
    assign head_o = fdc_head;
    assign drq2_o = fdc_drq && dor[3];
    assign irq6_o = fdc_irq && dor[3];

    // Digital input register (PDF 611-612): bit 7 = Diskette Change of the
    // selected drive; bits 6-0 belong to the fixed-disk function.
    // ASSUMPTION AT33 (see spec): bit 7 reads 1 while the selected drive's
    // change line is active; with no fixed-disk function modeled, bits 6-0
    // read 1.
    // The read data is held from the start of a read strobe: the slot
    // samples it at the end of the command (at_io_channel), and the
    // controller advances its result pointer at the strobe's leading edge.
    logic [7:0] live, held;
    logic reading;
    assign reading = !ior_n_i && (sel_dir || sel_fdc || (!dack2_n_i && fdc_oe));
    assign live = sel_dir ? {disk_change_i, 7'h7f} : fdc_d;
    always_ff @(posedge clk_i) if (ior_q && !ior_n_i) held <= live;
    assign d_o = ior_q ? live : held;
    assign d_oe_o = reading;

    logic unused;
    assign unused = ^{a_i[19:10], dor[7:6], dor[1], fdc_unit, fdc_load, fdc_deleted, sec_c, sec_h, sec_n,
                      sel_fdc && fdc_oe};
endmodule
