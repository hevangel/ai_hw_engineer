// AMD Am29338 32-bit byte queue (intelligent FIFO), edge-accurate
// digital model.
//
// Source: AMD 1988 Am29C300/29300 Data Book, "Am29338 32-Bit Byte
// Queue" advance information (PDF 242-263), pin descriptions,
// functional description, Figures 1-7 and Tables 1-4 (page images
// inspected).
//
// Four 32x9 RAM slices form a 128-byte ring with byte parity. Up to
// four bytes are queued per QCLK edge (Table 1) and up to sixteen
// dequeued per DQCLK edge (Table 2; values above four are meaningful
// only in horizontally cascaded systems - the pointer still advances
// per chip, see ledger). The input word is byte-reordered per the BSW
// pins (Table 3) and disassembled LSB-first; the output window presents
// the four bytes following the dequeue pointer LSB-aligned. RESET and
// RXMIT are asynchronous: the dequeue pointer takes the POS-programmed
// quadrant start (Table 4). The datasheet models the RAM writes during
// QCLK low with pointer updates at the edge; this model performs the
// writes at the edge (byte-stream equivalent - ledger).
module amd_am29338 (
  input  logic        qclk_i, dqclk_i,
  input  logic        qen_n_i, dqen_n_i,
  input  logic [1:0]  bq_i,        // bytes to queue, Table 1
  input  logic [3:0]  bdq_i,       // bytes to dequeue, Table 2
  input  logic [1:0]  bsw_i,       // input byte reorder, Table 3
  input  logic [31:0] d_i,
  input  logic [3:0]  pd_i,        // even-parity inputs, per input byte
  input  logic [1:0]  pos_i,       // cascade quadrant, Table 4
  input  logic        reset_n_i, rxmit_n_i,
  input  logic        oe_n_i,
  output logic [31:0] y_o,
  output logic        y_oe_o,
  output logic [3:0]  py_o,
  output logic        pyerr_o,
  output logic        pderr_o,
  output logic [6:0]  cnt_o,
  output logic        full_o, a_full_o, empty_o, a_empty_o
`ifdef FORMAL
  , input logic fml_clk_i          // formal-only property timebase
`endif
);

  // Storage: 128 bytes with stored even parity (four 32x9 slices).
  logic [8:0] mem [0:127];

  // Pointers (byte addresses, modulo 128) and the byte-count registers:
  // a queue count and a dequeue count whose combinational difference
  // drives the status outputs (datasheet Byte-Count Logic).
  logic [6:0] q_ptr, d_ptr;
  logic [7:0] q_cnt, d_cnt;
  wire [8:0] count = q_cnt - d_cnt;
  wire [7:0] count_sat = (count[8]) ? 8'd0 : (count > 9'd128 ? 8'd128
                                                             : count[7:0]);

  // Bytes queued per Table 1: 00->4, 01->1, 10->2, 11->3.
  wire [2:0] n_q = (bq_i == 2'b00) ? 3'd4 : (bq_i[1] ? 2'b10 + bq_i[0]
                                                    : {2'b0, bq_i[0]});
  // Bytes dequeued per Table 2: binary with 0 meaning 16.
  wire [4:0] n_dq = (bdq_i == 4'b0000) ? 5'd16 : {1'b0, bdq_i};

  // Input byte reordering per Table 3 (input bus = bytes A B C D,
  // A = least significant) with the original-position mapping: parity
  // bits travel with their bytes through the rotator, and the parity
  // check runs on the original D/PD lanes (Figure 1 checks before the
  // rotator).
  logic [7:0] in_byte [0:3];
  logic [3:0] in_par;                  // reordered parity bits
  logic [1:0] sel_orig [0:3];          // orig_of[k]: original lane of
  always_comb begin                    // reordered byte k
    in_byte[0] = d_i[7:0];
    in_byte[1] = d_i[15:8];
    in_byte[2] = d_i[23:16];
    in_byte[3] = d_i[31:24];
    sel_orig[0] = 2'd0; sel_orig[1] = 2'd1;
    sel_orig[2] = 2'd2; sel_orig[3] = 2'd3;
    case (bsw_i)
      2'b01: begin                     // B A D C -> orig 1,0,3,2
        in_byte[0] = d_i[15:8]; in_byte[1] = d_i[7:0];
        in_byte[2] = d_i[31:24]; in_byte[3] = d_i[23:16];
        sel_orig[0] = 2'd1; sel_orig[1] = 2'd0;
        sel_orig[2] = 2'd3; sel_orig[3] = 2'd2;
      end
      2'b10: begin                     // C D A B -> orig 2,3,0,1
        in_byte[0] = d_i[23:16]; in_byte[1] = d_i[31:24];
        in_byte[2] = d_i[7:0];   in_byte[3] = d_i[15:8];
        sel_orig[0] = 2'd2; sel_orig[1] = 2'd3;
        sel_orig[2] = 2'd0; sel_orig[3] = 2'd1;
      end
      2'b11: begin                     // D C B A -> orig 3,2,1,0
        in_byte[0] = d_i[31:24]; in_byte[1] = d_i[23:16];
        in_byte[2] = d_i[15:8];  in_byte[3] = d_i[7:0];
        sel_orig[0] = 2'd3; sel_orig[1] = 2'd2;
        sel_orig[2] = 2'd1; sel_orig[3] = 2'd0;
      end
      default: ;
    endcase
    in_par[0] = pd_i[sel_orig[0]];
    in_par[1] = pd_i[sel_orig[1]];
    in_par[2] = pd_i[sel_orig[2]];
    in_par[3] = pd_i[sel_orig[3]];
  end

  // Parity error on the bytes about to be queued, checked on the
  // original D/PD lanes (combinational).
  logic pderr_c;
  always_comb begin
    pderr_c = 1'b0;
    for (int k = 0; k < 4; k++)
      if (k < n_q)
        if (pd_i[sel_orig[k]] != (^in_byte[k])) pderr_c = 1'b1;
  end
  assign pderr_o = pderr_c;

  // Output window: the four bytes following the dequeue pointer,
  // LSB-aligned, with the stored parity bits and the recomputed check.
  logic [7:0] y_byte [0:3];
  logic [3:0] y_par;
  always_comb begin
    for (int k = 0; k < 4; k++) begin
      y_byte[k] = mem[7'((d_ptr + 7'(k)) & 7'd127)][7:0];
      y_par[k]  = mem[7'((d_ptr + 7'(k)) & 7'd127)][8];
    end
  end
  assign y_o    = {y_byte[3], y_byte[2], y_byte[1], y_byte[0]};
  assign y_oe_o = !oe_n_i;
  assign py_o   = y_par;
  logic pyerr_c;
  always_comb begin
    pyerr_c = 1'b0;
    for (int k = 0; k < 4; k++)
      if (y_par[k] != (^y_byte[k])) pyerr_c = 1'b1;
  end
  assign pyerr_o = y_oe_o && pyerr_c;

  // Status (queue minus dequeue count, saturating for the per-chip
  // cascade view; see ledger for overflow/underflow resolution).
  assign cnt_o     = count_sat[6:0];
  assign full_o    = (count_sat == 8'd128);
  assign a_full_o  = (count_sat > 8'd124);
  assign empty_o   = (count_sat == 8'd0);
  assign a_empty_o = (count_sat < 8'd4);

  // Bytes accepted per queue edge: dropped beyond 128 total (model
  // choice for the undocumented full-write case).
  wire [8:0] space = 9'd128 - {1'b0, count_sat};
  wire [2:0] n_acc = (space >= {6'd0, n_q}) ? n_q : space[2:0];

  // Sequential behavior. QCLK/DQCLK are independent clocks (the model
  // supports asynchronous operation, which subsumes synchronous).
  // RESET and RXMIT are asynchronous with priority; RESET clears both
  // counts and the queue pointer while the dequeue pointer takes the
  // POS-programmed quadrant start; RXMIT rewinds the dequeue side only.
  always_ff @(posedge qclk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
      q_ptr <= 7'd0;
      q_cnt <= 8'd0;
    end else if (!qen_n_i) begin
      for (int k = 0; k < 4; k++)
        if (k < n_acc)
          mem[7'((q_ptr + 7'(k)) & 7'd127)] <= {in_par[k], in_byte[k]};
      q_ptr <= q_ptr + {4'd0, n_acc};
      q_cnt <= (q_cnt + {5'd0, n_acc} > 8'd128) ? 8'd128
               : q_cnt + {5'd0, n_acc};
    end
  end
  // RESET is asynchronous with priority. RXMIT is sampled at DQCLK
  // edges (synchronous assertion) - a documented model choice, since a
  // single always_ff cannot carry a second independent async control
  // here (see spec ledger).
  always_ff @(posedge dqclk_i or negedge reset_n_i) begin
    if (!reset_n_i) begin
      d_ptr <= 7'(32 * pos_i);
      d_cnt <= 8'd0;
    end else if (!rxmit_n_i) begin
      d_ptr <= 7'(32 * pos_i);
      d_cnt <= 8'(32 * pos_i);
    end else if (!dqen_n_i) begin
      d_ptr <= 7'((d_ptr + {2'b00, n_dq}) & 7'd127);
      d_cnt <= (d_cnt + {3'd0, n_dq} > 9'd128) ? 8'd128 : d_cnt + {3'd0, n_dq};
    end
  end

`ifdef FORMAL
  `include "amd_am29338_props.sv"
`endif
endmodule
