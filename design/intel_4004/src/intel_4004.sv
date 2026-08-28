`timescale 1ns/1ps

// Intel 4004 microprocessor: synchronous, synthesizable functional
// reconstruction. See spec/spec.md for the complete behavioral contract.
// The historical part runs two non-overlapping clock phases and groups eight
// clock periods (A1 A2 A3 M1 M2 X1 X2 X3) into one instruction cycle; this
// core advances one internal phase per clk edge and commits all architectural
// state on the single edge that ends the instruction's final X3. The program
// counter is held at the address of the word being fetched and the advanced
// value (PC + 1 per cycle) is applied at the commit edge, which reproduces
// the historical increment-at-A1 page quirks of JCN/JIN/FIN/ISZ exactly.
module intel_4004 (
    input  logic       clk,
    input  logic       rst_n,

    // Historical TEST pin (JCN condition code C4 samples it low)
    input  logic       test_i,

    // Multiplexed 4-bit data bus, split into input/output/output-enable
    input  logic [3:0] data_i,
    output logic [3:0] data_o,
    output logic       data_oe,

    // Command lines
    output logic       sync,
    output logic       cm_rom,
    output logic [3:0] cm_ram
);

  // Phase encoding: one instruction cycle = A1 A2 A3 M1 M2 X1 X2 X3
  localparam logic [2:0] PhA1 = 3'd0;
  localparam logic [2:0] PhA2 = 3'd1;
  localparam logic [2:0] PhA3 = 3'd2;
  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX1 = 3'd5;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  // OPR (opcode high nibble) groups
  localparam logic [3:0] OprNop    = 4'h0;
  localparam logic [3:0] OprJcn    = 4'h1;
  localparam logic [3:0] OprFimSrc = 4'h2;
  localparam logic [3:0] OprFinJin = 4'h3;
  localparam logic [3:0] OprJun    = 4'h4;
  localparam logic [3:0] OprJms    = 4'h5;
  localparam logic [3:0] OprInc    = 4'h6;
  localparam logic [3:0] OprIsz    = 4'h7;
  localparam logic [3:0] OprAdd    = 4'h8;
  localparam logic [3:0] OprSub    = 4'h9;
  localparam logic [3:0] OprLd     = 4'ha;
  localparam logic [3:0] OprXch    = 4'hb;
  localparam logic [3:0] OprBbl    = 4'hc;
  localparam logic [3:0] OprLdm    = 4'hd;
  localparam logic [3:0] OprIo     = 4'he;
  localparam logic [3:0] OprAcc    = 4'hf;

  // Architectural state
  logic [1:0]  sp;
  logic [11:0] stack [4];  // stack[sp] is the program counter
  logic [3:0]  acc;
  logic        cy;
  logic [3:0]  idx [16];
  logic [7:0]  src_ptr;
  logic [2:0]  cmd;

  // Sequencer and fetch state
  logic [2:0] phase;
  logic       cycle2;    // 1 during the second instruction cycle
  logic [3:0] opr;       // word-1 high nibble (latched at M1)
  logic [3:0] opa;       // word-1 low nibble (latched at M2)
  logic [3:0] word2_hi;  // second-word high nibble (cycle 2, M1)
  logic [3:0] word2_lo;  // second-word low nibble (cycle 2, M2)

  logic [11:0] pc;
  assign pc = stack[sp];

  logic [11:0] pc_plus1;
  logic [11:0] pc_plus2;
  assign pc_plus1 = pc + 12'd1;
  assign pc_plus2 = pc + 12'd2;

  // Word-1 decode
  logic       src_word;  // SRC 0010 RRR1
  logic       fin_word;  // FIN 0011 RRR0
  logic       fim_word;  // FIM 0010 RRR0
  logic       two_cycle; // instruction needs a second instruction cycle
  logic [2:0] reg_pair;  // RRR field of FIM/SRC/FIN/JIN
  assign src_word = (opr == OprFimSrc) && opa[0];
  assign fim_word = (opr == OprFimSrc) && !opa[0];
  assign fin_word = (opr == OprFinJin) && !opa[0];
  assign reg_pair = opa[3:1];
  assign two_cycle = (opr == OprJcn) || (opr == OprJun) || (opr == OprJms) ||
                     (opr == OprIsz) || fim_word || fin_word;

  // Second instruction cycle of FIN drives the pair-0 pointer instead of PC
  logic fin_fetch;
  assign fin_fetch = cycle2 && fin_word;

  // Address driven during A1-A3 of the current cycle
  logic [11:0] fetch_addr;
  assign fetch_addr = cycle2 ? (fin_fetch ? {pc_plus1[11:8], idx[0], idx[1]}
                                          : pc_plus1)
                             : pc;

  // OPR = 1110 RAM/ROM port operation decode
  logic io_word;
  logic io_write;    // drive ACC at X2/X3
  logic io_ram;      // RAM-side operation (assert cm_ram at X2/X3)
  logic io_romport;  // ROM-side operation (assert cm_rom at X2/X3)
  assign io_word = (opr == OprIo);
  assign io_write = io_word && (opa <= 4'h7);  // WRM..WR3, incl. WPM
  assign io_romport = io_word && ((opa == 4'h2) || (opa == 4'h3) ||
                                  (opa == 4'ha));  // WRR, WPM, RDR
  assign io_ram = io_word && !io_romport;

  // JCN condition (spec 5.4). C1 = invert, C2 = ACC zero, C3 = CY, C4 = TEST
  logic jcn_raw;
  logic jcn_taken;
  assign jcn_raw = ((opa[2] && (acc == 4'h0)) ||
                    (opa[1] && cy) ||
                    (opa[0] && !test_i));
  assign jcn_taken = opa[3] ? !jcn_raw : jcn_raw;

  // ISZ branches when the incremented register is non-zero
  logic isz_taken;
  assign isz_taken = (idx[opa] != 4'hf);

  // KBP one-hot encoder (spec 5.3)
  function automatic logic [3:0] kbp_encode(input logic [3:0] v);
    case (v)
      4'h0:    kbp_encode = 4'h0;
      4'h1:    kbp_encode = 4'h1;
      4'h2:    kbp_encode = 4'h2;
      4'h4:    kbp_encode = 4'h3;
      4'h8:    kbp_encode = 4'h4;
      default: kbp_encode = 4'hf;
    endcase
  endfunction

  // Bus output multiplexing (spec 6.1, 6.3)
  always_comb begin
    data_o  = 4'h0;
    data_oe = 1'b0;
    case (phase)
      PhA1: begin
        data_o  = fetch_addr[3:0];
        data_oe = 1'b1;
      end
      PhA2: begin
        data_o  = fetch_addr[7:4];
        data_oe = 1'b1;
      end
      PhA3: begin
        data_o  = fetch_addr[11:8];
        data_oe = 1'b1;
      end
      PhX2, PhX3: begin
        if (src_word) begin
          data_o  = (phase == PhX2) ? idx[{reg_pair, 1'b0}]
                                    : idx[{reg_pair, 1'b1}];
          data_oe = 1'b1;
        end else if (io_write) begin
          data_o  = acc;
          data_oe = 1'b1;
        end
      end
      default: ;
    endcase
  end

  assign sync   = (phase == PhA1);
  assign cm_rom = (phase <= PhA3) ||
                  ((phase == PhX2 || phase == PhX3) && io_romport);

  // DCL command-line decode (spec 5.3): line 0 with no bits set, lines 1-3
  // follow CMD bits 0-2 directly.
  logic [3:0] cm_ram_sel;
  assign cm_ram_sel = {cmd[2], cmd[1], cmd[0], ~|cmd};
  assign cm_ram = (phase == PhX2 || phase == PhX3) && (src_word || io_ram)
                    ? cm_ram_sel
                    : 4'b0000;

  // Architectural commit point: end of the instruction's final X3
  logic instr_end;
  assign instr_end = (phase == PhX3) && (cycle2 || !two_cycle);

  logic [1:0] sp_next;
  always_comb begin
    unique case (opr)
      OprJms:  sp_next = sp + 2'd1;  // push (rotating 4-register stack)
      OprBbl:  sp_next = sp - 2'd1;  // pop
      default: sp_next = sp;
    endcase
  end

  // Next program counter, computed as a single value: sequential advance
  // past the fetched word(s), overridden by the branch/commit targets. A
  // single write per element keeps the update unambiguous across simulators.
  logic [11:0] pc_next;
  always_comb begin
    pc_next = cycle2 ? pc_plus2 : pc_plus1;
    unique case (opr)
      OprJcn: begin
        if (jcn_taken) begin
          pc_next = {pc_plus2[11:8], word2_hi, word2_lo};
        end
      end
      OprFinJin: begin
        if (!fin_word) begin  // JIN: PC[7:0] from pair, page of next word
          pc_next = {pc_plus1[11:8], idx[{reg_pair, 1'b0}],
                     idx[{reg_pair, 1'b1}]};
        end
      end
      OprJun, OprJms: begin
        pc_next = {opa, word2_hi, word2_lo};
      end
      OprIsz: begin
        if (isz_taken) begin
          pc_next = {pc_plus2[11:8], word2_hi, word2_lo};
        end
      end
      default: ;
    endcase
  end

  integer i;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      phase    <= PhA1;
      cycle2   <= 1'b0;
      acc      <= 4'h0;
      cy       <= 1'b0;
      sp       <= 2'd0;
      src_ptr  <= 8'h0;
      cmd      <= 3'b000;
      opr      <= 4'h0;
      opa      <= 4'h0;
      word2_hi <= 4'h0;
      word2_lo <= 4'h0;
      for (i = 0; i < 4; i++) begin
        stack[i] <= 12'h0;
      end
      for (i = 0; i < 16; i++) begin
        idx[i] <= 4'h0;
      end
      // The historical RESET pin clears all registers including the index
      // register array when held long enough to refresh it (spec 6.4).
    end else begin
      // Phase and cycle sequencing
      if (phase == PhX3) begin
        phase  <= PhA1;
        cycle2 <= !cycle2 && two_cycle;
      end else begin
        phase <= phase + 3'd1;
      end

      // Fetch latches: word-1 at M1/M2 of cycle 1, word-2 at M1/M2 of cycle 2
      if (phase == PhM1) begin
        if (cycle2) begin
          word2_hi <= data_i;
        end else begin
          opr <= data_i;
        end
      end
      if (phase == PhM2) begin
        if (cycle2) begin
          word2_lo <= data_i;
        end else begin
          opa <= data_i;
        end
      end

      // Architectural commit at the end of the instruction's final X3
      if (instr_end) begin
        stack[sp] <= pc_next;

        unique case (opr)
          OprFimSrc: begin
            if (fim_word) begin
              idx[{reg_pair, 1'b0}] <= word2_hi;
              idx[{reg_pair, 1'b1}] <= word2_lo;
            end else begin  // SRC
              src_ptr <= {idx[{reg_pair, 1'b0}], idx[{reg_pair, 1'b1}]};
            end
          end
          OprFinJin: begin
            if (fin_word) begin
              idx[{reg_pair, 1'b0}] <= word2_hi;
              idx[{reg_pair, 1'b1}] <= word2_lo;
            end
          end
          OprJms: begin
            stack[sp]      <= pc_plus2;  // return address in current slot
            stack[sp_next] <= {opa, word2_hi, word2_lo};
            sp             <= sp_next;
          end
          OprInc: begin
            idx[opa] <= idx[opa] + 4'd1;
          end
          OprIsz: begin
            idx[opa] <= idx[opa] + 4'd1;
          end
          OprAdd: begin
            {cy, acc} <= acc + idx[opa] + {3'b000, cy};
          end
          OprSub: begin
            // Subtract adds the inverted carry: CY=0 means a pending borrow
            {cy, acc} <= acc + {1'b0, ~idx[opa]} + {3'b000, ~cy};
          end
          OprLd: begin
            acc <= idx[opa];
          end
          OprXch: begin
            acc      <= idx[opa];
            idx[opa] <= acc;
          end
          OprBbl: begin
            sp  <= sp - 2'd1;
            acc <= opa;
          end
          OprLdm: begin
            acc <= opa;
          end
          OprIo: begin
            case (opa)
              4'h8: begin  // SBM: inverted carry, same sense as SUB
                {cy, acc} <= acc + {1'b0, ~data_i} + {3'b000, ~cy};
              end
              4'h9, 4'ha: begin  // RDM, RDR
                acc <= data_i;
              end
              4'hb: begin  // ADM
                {cy, acc} <= acc + data_i + {3'b000, cy};
              end
              4'hc, 4'hd, 4'he, 4'hf: begin  // RD0-RD3
                acc <= data_i;
              end
              default: ;  // writes (WRM/WMP/WRR/WPM/WR0-3): memory-side only
            endcase
          end
          OprAcc: begin
            case (opa)
              4'h0: begin  // CLB
                acc <= 4'h0;
                cy  <= 1'b0;
              end
              4'h1: cy <= 1'b0;  // CLC
              4'h2: begin  // IAC
                {cy, acc} <= acc + 4'd1;
              end
              4'h3: cy <= ~cy;  // CMC
              4'h4: acc <= ~acc;  // CMA
              4'h5: {cy, acc} <= {acc, cy};  // RAL
              4'h6: {cy, acc} <= {acc[0], cy, acc[3:1]};  // RAR
              4'h7: begin  // TCC
                acc <= {3'b000, cy};
                cy  <= 1'b0;
              end
              4'h8: begin  // DAC
                {cy, acc} <= acc + 4'hf;
              end
              4'h9: begin  // TCS
                acc <= cy ? 4'h9 : 4'ha;
                cy  <= 1'b0;
              end
              4'ha: cy <= 1'b1;  // STC
              4'hb: begin  // DAA
                if (cy || acc > 4'd9) begin
                  {cy, acc} <= acc + 4'd6;
                end
              end
              4'hc: acc <= kbp_encode(acc);  // KBP
              4'hd: cmd <= acc[2:0];  // DCL
              default: ;  // 1111 1110 / 1111 1111: NOP
            endcase
          end
          default: ;  // NOP
        endcase
      end
    end
  end

`ifdef FORMAL
  // Structural safety (main properties live in formal/intel_4004_props.sv)
  always @(posedge clk) begin
    if (rst_n) begin
      a_phase_range: assert (phase <= PhX3);
      a_sync_a1: assert (sync == (phase == PhA1));
      a_cm_rom: assert (cm_rom == ((phase <= PhA3) ||
                                   ((phase == PhX2 || phase == PhX3) &&
                                    io_romport)));
      a_data_oe: assert (!data_oe ||
                         (phase == PhA1) || (phase == PhA2) ||
                         (phase == PhA3) || (phase == PhX2) ||
                         (phase == PhX3));
    end
  end

`ifdef FORMAL_COVER
  intel_4004_cover formal_coverage (
      .clk      (clk),
      .rst_n    (rst_n),
      .test_i   (test_i),
      .data_i   (data_i),
      .data_o   (data_o),
      .data_oe  (data_oe),
      .sync     (sync),
      .cm_rom   (cm_rom),
      .cm_ram   (cm_ram),
      .phase    (phase),
      .cycle2   (cycle2),
      .opr      (opr),
      .opa      (opa),
      .sp       (sp),
      .acc      (acc),
      .cy       (cy),
      .src_ptr  (src_ptr),
      .cmd      (cmd),
      .pc       (pc),
      .two_cycle (two_cycle),
      .jcn_taken (jcn_taken),
      .isz_taken (isz_taken)
  );
`else
  intel_4004_props formal_properties (
      .clk      (clk),
      .rst_n    (rst_n),
      .test_i   (test_i),
      .data_i   (data_i),
      .data_o   (data_o),
      .data_oe  (data_oe),
      .sync     (sync),
      .cm_rom   (cm_rom),
      .cm_ram   (cm_ram),
      .phase    (phase),
      .cycle2   (cycle2),
      .opr      (opr),
      .opa      (opa),
      .instr_end (instr_end),
      .sp       (sp),
      .stack0   (stack[0]),
      .stack1   (stack[1]),
      .stack2   (stack[2]),
      .stack3   (stack[3]),
      .acc      (acc),
      .cy       (cy),
      .idx_flat ({idx[15], idx[14], idx[13], idx[12],
                  idx[11], idx[10], idx[9],  idx[8],
                  idx[7],  idx[6],  idx[5],  idx[4],
                  idx[3],  idx[2],  idx[1],  idx[0]}),
      .src_ptr  (src_ptr),
      .cmd      (cmd)
  );
`endif
`endif

  // Intentionally unused state and encoding-table entries: the SRC pointer is
  // consumed only by the (external) memory system on the bus, never read back
  // by the CPU itself, and X1/NOP carry no dedicated behavior.
  logic _unused;
  assign _unused = &{1'b0, src_ptr, PhX1, OprNop};

endmodule
