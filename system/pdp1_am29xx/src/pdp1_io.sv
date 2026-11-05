`timescale 1ns/1ps
// PDP-1 standard console and I/O devices: paper-tape reader and punch,
// typewriter, Type 30 point-plot display, program flags, sequence-break
// control and the check-status word.
//
// Functional models only (spec.md A11): no electromechanical timing, no
// punched-tape mechanics and no analog CRT. Host queues provide tape words
// and keyboard characters; the machine's wait states are its own.
`ifndef PDP1_IO_SV
`define PDP1_IO_SV

module pdp1_io (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [17:0] tw_i,
    input  logic [5:0]  ss_i,
    // Device strobe from the microcode.
    input  logic        dev_strobe_i,
    input  logic [5:0]  dev_i,
    input  logic [5:0]  pulse_i,
    input  logic [17:0] io_i,
    input  logic [17:0] ac_i,
    output logic [17:0] devdata_o,
    input  logic        kbd_valid_i,
    input  logic [17:0] kbd_data_i,
    output logic        kbd_pop_o,
    input  logic        tape_valid_i,
    input  logic [17:0] tape_data_i,
    output logic        tape_pop_o,
    output logic [17:0] tty_data_o,
    output logic        tty_stb_o,
    output logic [17:0] punch_data_o,
    output logic        punch_stb_o,
    output logic [9:0]  dpy_x_o,
    output logic [9:0]  dpy_y_o,
    output logic [2:0]  dpy_int_o,
    output logic        dpy_stb_o,
    input  logic [5:0]  flag_set_i,
    input  logic [5:0]  flag_clr_i,
    output logic [5:0]  flag_o,
    input  logic        sbs_set_i,
    input  logic        sbs_clr_i,
    output logic        sbs_enb_o,
    input  logic        sbs_req_i,
    output logic        sbs_pending_o,
    input  logic        sbs_ack_i,
    output logic [17:0] status_o
);

  localparam logic [5:0] DEV_READER  = 6'o01;
  localparam logic [5:0] DEV_READER2 = 6'o02;
  localparam logic [5:0] DEV_TTO     = 6'o03;
  localparam logic [5:0] DEV_TTI     = 6'o04;
  localparam logic [5:0] DEV_PUNCH   = 6'o05;
  localparam logic [5:0] DEV_PUNCH2  = 6'o06;
  localparam logic [5:0] DEV_DPY     = 6'o07;
  localparam logic [5:0] DEV_CONTROL = 6'o11;
  localparam logic [5:0] DEV_READBUF = 6'o30;
  localparam logic [5:0] DEV_STATUS  = 6'o33;
  localparam logic [5:0] DEV_LSM     = 6'o54;
  localparam logic [5:0] DEV_ESM     = 6'o55;

  logic [17:0] tty_q, punch_q;
  logic        tty_stb_q, punch_stb_q;
  logic [9:0]  dpy_x_q, dpy_y_q;
  logic [2:0]  dpy_int_q;
  logic        dpy_stb_q;
  logic        sbs_enb_q;
  logic        sbs_pend_q;
  logic [5:0]  flag_q;
  logic        kbd_pop_q, tape_pop_q;
  logic [17:0] devdata_q;
  logic [9:0]  dpy_x_c, dpy_y_c;

  assign flag_o = flag_q;
  assign sbs_enb_o = sbs_enb_q;
  assign sbs_pending_o = sbs_pend_q && sbs_enb_q;
  assign tty_data_o = tty_q;
  assign tty_stb_o = tty_stb_q;
  assign punch_data_o = punch_q;
  assign punch_stb_o = punch_stb_q;
  assign dpy_x_o = dpy_x_q;
  assign dpy_y_o = dpy_y_q;
  assign dpy_int_o = dpy_int_q;
  assign dpy_stb_o = dpy_stb_q;
  assign kbd_pop_o = kbd_pop_q;
  assign tape_pop_o = tape_pop_q;
  assign devdata_o = devdata_q;

  // Check-status word. Documented subset: bit 0 keyboard data available,
  // bit 1 tape word available, bit 2 sequence break enabled, bit 3 break
  // pending. Other original status bits (printer, punch, drum, channel
  // flags) are out of profile.
  assign status_o = {14'd0, sbs_pend_q, sbs_enb_q, tape_valid_i, kbd_valid_i};

  // Type 30 point plot: X from AC<8:17>, Y from IO<8:17>. The -511..+511 to
  // 0..1022 conversion follows the ten-bit DAC range as implemented by the
  // independent SIMH Type 30 model.
  function automatic logic [9:0] dac_scale(input logic [9:0] value);
    if (value[9]) begin
      dac_scale = {1'b0, value[8:0]} ^ 10'h100;
    end else begin
      dac_scale = value + 10'd511;
    end
  endfunction

  assign dpy_x_c = dac_scale(ac_i[17:8]);
  assign dpy_y_c = dac_scale(io_i[17:8]);

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      tty_q <= 18'd0;
      punch_q <= 18'd0;
      tty_stb_q <= 1'b0;
      punch_stb_q <= 1'b0;
      dpy_x_q <= 10'd511;
      dpy_y_q <= 10'd511;
      dpy_int_q <= 3'd0;
      dpy_stb_q <= 1'b0;
      sbs_enb_q <= 1'b0;
      sbs_pend_q <= 1'b0;
      flag_q <= 6'd0;
      kbd_pop_q <= 1'b0;
      tape_pop_q <= 1'b0;
      devdata_q <= 18'd0;
    end else begin
      tty_stb_q <= 1'b0;
      punch_stb_q <= 1'b0;
      dpy_stb_q <= 1'b0;
      kbd_pop_q <= 1'b0;
      tape_pop_q <= 1'b0;
      flag_q <= (flag_q & ~flag_clr_i) | flag_set_i;

      if (sbs_set_i) sbs_enb_q <= 1'b1;
      if (sbs_clr_i) sbs_enb_q <= 1'b0;
      if (sbs_req_i) sbs_pend_q <= 1'b1;
      if (sbs_ack_i) sbs_pend_q <= 1'b0;

      if (dev_strobe_i) begin
        unique case (dev_i)
          DEV_READER, DEV_READER2, DEV_READBUF: begin
            if (tape_valid_i) begin
              devdata_q <= tape_data_i;
              tape_pop_q <= 1'b1;
            end
          end
          DEV_TTO: begin
            tty_q <= io_i;
            tty_stb_q <= 1'b1;
          end
          DEV_TTI: begin
            if (kbd_valid_i) begin
              devdata_q <= kbd_data_i;
              kbd_pop_q <= 1'b1;
            end
          end
          DEV_PUNCH, DEV_PUNCH2: begin
            punch_q <= io_i;
            punch_stb_q <= 1'b1;
          end
          DEV_DPY: begin
            dpy_x_q <= dpy_x_c;
            dpy_y_q <= dpy_y_c;
            dpy_int_q <= pulse_i[2:0];
            dpy_stb_q <= 1'b1;
          end
          DEV_CONTROL: devdata_q <= tw_i;
          DEV_STATUS: begin
            devdata_q <= {14'd0, sbs_pend_q, sbs_enb_q, tape_valid_i, kbd_valid_i};
          end
          DEV_ESM: sbs_enb_q <= 1'b1;
          DEV_LSM: sbs_enb_q <= 1'b0;
          default: ;
        endcase
      end
    end
  end

endmodule

`endif
