// Console and paper-tape peripherals for the PDP-8 reconstruction.
//
//   device 00  CPU        ION (6001), IOF (6002)
//   device 01  reader     PRS (6011), RRB (6012), RFC (6014)
//   device 02  punch      PPS (6021), PPB (6022)
//   device 03  keyboard   KSF (6031), KCC (6032), KRS (6034), KRB (6036)
//   device 04  printer    TSF (6041), TCF (6042), TPC (6044), TLS (6046)
//
// Pulse meanings follow the machine: bit 0 (001) tests and skips, bit 1 (002)
// clears a flag or returns a buffer, bit 2 (004) starts a read or transfers
// data.  KCC also clears the accumulator, which is why the CPU asks
// iot_clr_ac_o during the strobe cycle and ors iot_data_o in the next cycle.
//
// Timing is functional: a character is printed or punched in the strobe cycle
// and its flag is already valid in the following cycle.  The physical ASR-33
// runs at 110 baud; this model does not reproduce character timing.
`timescale 1ns/1ps
module pdp8_console (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic [11:0] ir_i,
    input  logic [1:0]  iot_ph_i,
    input  logic [11:0] y_i,
    output logic [11:0] iot_data_o,
    output logic        iot_clr_ac_o,
    output logic        iot_data_we_o,
    output logic        iot_skip_o,
    output logic        ion_set_o,
    output logic        iof_set_o,
    output logic        int_req_o,
    // host interfaces
    input  logic [7:0]  kb_data_i,
    input  logic        kb_valid_i,
    output logic        kb_ready_o,
    output logic        kb_take_o,
    output logic [7:0]  tty_data_o,
    output logic        tty_valid_o,
    input  logic [7:0]  ptr_data_i,
    input  logic        ptr_valid_i,
    output logic        ptr_take_o,
    output logic [7:0]  ptp_data_o,
    output logic        ptp_valid_o
);
  logic [5:0] dev;
  logic [2:0] pulse;
  assign dev   = ir_i[8:3];
  assign pulse = ir_i[2:0];

  logic [7:0] kb_buf, ptr_buf, data_latch;
  logic [7:0] tty_buf, ptp_buf;
  logic       kb_flag, ptr_flag, tty_flag, ptp_flag;

  assign kb_ready_o = ~kb_flag;
  assign int_req_o  = kb_flag | ptr_flag | tty_flag | ptp_flag;

  // Data presented to the accumulator in the second I/O cycle.
  assign iot_data_o    = {4'b0000, data_latch};
  assign iot_data_we_o = (iot_ph_i == 2'd2) &&
                         ((dev == 6'd1 && pulse[1]) || (dev == 6'd3 && pulse[2]));
  assign iot_clr_ac_o  = (iot_ph_i == 2'd1) && (dev == 6'd3) && pulse[1];
  assign iot_skip_o    = (iot_ph_i == 2'd2) &&
                         ((dev == 6'd1 && pulse[0] && ptr_flag) ||
                          (dev == 6'd2 && pulse[0] && ptp_flag) ||
                          (dev == 6'd3 && pulse[0] && kb_flag) ||
                          (dev == 6'd4 && pulse[0] && tty_flag));
  assign ion_set_o     = (iot_ph_i == 2'd1) && (dev == 6'd0) && (pulse == 3'o1);
  assign iof_set_o     = (iot_ph_i == 2'd1) && (dev == 6'd0) && (pulse == 3'o2);

  assign kb_take_o  = (iot_ph_i == 2'd1) && (dev == 6'd3) && pulse[2] && kb_valid_i;
  assign ptr_take_o = (iot_ph_i == 2'd1) && (dev == 6'd1) && pulse[2] && ptr_valid_i;

  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      kb_buf     <= 8'h00;
      kb_flag    <= 1'b0;
      ptr_buf    <= 8'h00;
      ptr_flag   <= 1'b0;
      // The teleprinter is idle at power-on, so TSF is true until a character
      // is loaded; the flag then sets again when that character is accepted.
      tty_flag   <= 1'b1;
      ptp_flag   <= 1'b0;
      tty_buf    <= 8'h00;
      ptp_buf    <= 8'h00;
      tty_valid_o <= 1'b0;
      ptp_valid_o <= 1'b0;
      data_latch <= 8'h00;
    end else begin
      tty_valid_o <= 1'b0;
      ptp_valid_o <= 1'b0;

      // Keyboard input is captured whenever the flag is clear.
      if (kb_valid_i && !kb_flag) begin
        kb_buf  <= kb_data_i;
        kb_flag <= 1'b1;
      end

      if (iot_ph_i == 2'd1) begin
        // Capture the byte that the second cycle returns, before any update.
        case (dev)
          6'd1:    data_latch <= ptr_buf;
          6'd3:    data_latch <= kb_buf;
          default: data_latch <= 8'h00;
        endcase

        case (dev)
          6'd1: begin
            if (pulse[1]) ptr_flag <= 1'b0;
            if (pulse[2] && ptr_valid_i) begin
              ptr_buf  <= ptr_data_i;
              ptr_flag <= 1'b1;
            end
          end
          6'd2: begin
            if (pulse[1]) begin
              ptp_buf     <= y_i[7:0];
              ptp_valid_o <= 1'b1;
              ptp_flag    <= 1'b1;
            end
          end
          6'd3: begin
            if (pulse[1]) kb_flag <= 1'b0;
          end
          6'd4: begin
            if (pulse[1]) tty_flag <= 1'b0;
            if (pulse[2]) begin
              tty_buf     <= y_i[7:0];
              tty_valid_o <= 1'b1;
              tty_flag    <= 1'b1;
            end
          end
          default: ;
        endcase
      end
    end
  end

  assign tty_data_o = tty_buf;
  assign ptp_data_o = ptp_buf;
endmodule
