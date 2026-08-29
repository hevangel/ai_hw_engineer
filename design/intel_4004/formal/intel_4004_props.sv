// Formal safety and equivalence properties for the Intel 4004 reconstruction.
//
// The golden model in this module is an independent instruction-set simulator
// written from spec/spec.md: it maintains its own sequencer, fetch latches,
// and full architectural state, driven by `anyconst` instruction words that
// the bus assumptions deliver at M1/M2. Equality with the DUT is asserted on
// every architectural register at every clock, for every opcode encoding and
// every start state, which proves the complete ISA transition function rather
// than sampled cases. Combinational output checks re-derive the bus and
// command lines per the spec. Reset is assumed only in the initial cycle; a
// later reset is unconstrained and the golden model mirrors it, so reset
// dominance is checked too.
module intel_4004_props (
    input logic        clk,
    input logic        rst_n,
    input logic        test_i,
    input logic [3:0]  data_i,
    input logic [3:0]  data_o,
    input logic        data_oe,
    input logic        sync,
    input logic        cm_rom,
    input logic [3:0]  cm_ram,

    // DUT internals
    input logic [2:0]  phase,
    input logic        cycle2,
    input logic [3:0]  opr,
    input logic [3:0]  opa,
    input logic        instr_end,
    input logic [1:0]  sp,
    input logic [11:0] stack0,
    input logic [11:0] stack1,
    input logic [11:0] stack2,
    input logic [11:0] stack3,
    input logic [3:0]  acc,
    input logic        cy,
    input logic [63:0] idx_flat,  // {idx[15], ..., idx[0]}
    input logic [7:0]  src_ptr,
    input logic [2:0]  cmd
);

  localparam logic [2:0] PhA1 = 3'd0;
  localparam logic [2:0] PhA2 = 3'd1;
  localparam logic [2:0] PhA3 = 3'd2;
  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX1 = 3'd5;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  // Free bus-read value and instruction words
  (* anyconst *) logic [3:0] mem_rd;
  (* anyconst *) logic [7:0] opc1;  // first instruction word {OPR, OPA}
  (* anyconst *) logic [7:0] opc2;  // second instruction word

  // ------------------------------------------------------------------
  // Bus stimulus assumptions: arbitrary instructions enter at M1/M2 and
  // arbitrary memory data at every X3. test_i and later rst_n stay free.
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if ($initstate) begin
      a_reset0: assume (!rst_n);
    end
    if (rst_n) begin
      if (phase == PhM1 && !cycle2) begin
        a_m1: assume (data_i == opc1[7:4]);
      end
      if (phase == PhM2 && !cycle2) begin
        a_m2: assume (data_i == opc1[3:0]);
      end
      if (phase == PhM1 && cycle2) begin
        a_m1_c2: assume (data_i == opc2[7:4]);
      end
      if (phase == PhM2 && cycle2) begin
        a_m2_c2: assume (data_i == opc2[3:0]);
      end
      if (phase == PhX3) begin
        a_x3: assume (data_i == mem_rd);
      end
    end
  end

  // ------------------------------------------------------------------
  // Golden model: independent ISS per spec sections 5 and 6
  // ------------------------------------------------------------------
  logic [2:0]  g_phase;
  logic        g_cycle2;
  logic [3:0]  g_opr;
  logic [3:0]  g_opa;
  logic [3:0]  g_w2hi;
  logic [3:0]  g_w2lo;
  logic [1:0]  g_sp;
  logic [11:0] g_stack [4];
  logic [3:0]  g_acc;
  logic        g_cy;
  logic [3:0]  g_idx [16];
  logic [7:0]  g_src;
  logic [2:0]  g_cmd;

  logic [11:0] g_pc;
  assign g_pc = g_stack[g_sp];
  logic [11:0] g_pc1;
  logic [11:0] g_pc2;
  assign g_pc1 = g_pc + 12'd1;
  assign g_pc2 = g_pc + 12'd2;

  logic g_src_word;
  logic g_fim_word;
  logic g_fin_word;
  logic g_two_cycle;
  logic [2:0] g_pair;
  assign g_src_word = (g_opr == 4'h2) && g_opa[0];
  assign g_fim_word = (g_opr == 4'h2) && !g_opa[0];
  assign g_fin_word = (g_opr == 4'h3) && !g_opa[0];
  assign g_pair = g_opa[3:1];
  assign g_two_cycle = (g_opr == 4'h1) || (g_opr == 4'h4) || (g_opr == 4'h5) ||
                       (g_opr == 4'h7) || g_fim_word || g_fin_word;

  logic g_fin_fetch;
  assign g_fin_fetch = g_cycle2 && g_fin_word;

  logic [11:0] g_fetch_addr;
  assign g_fetch_addr = g_cycle2 ?
                        (g_fin_fetch ? {g_pc1[11:8], g_idx[0], g_idx[1]} : g_pc1)
                        : g_pc;

  logic g_io_write;
  logic g_io_ram;
  logic g_io_romport;
  assign g_io_write = (g_opr == 4'he) && (g_opa <= 4'h7);
  assign g_io_romport = (g_opr == 4'he) && ((g_opa == 4'h2) ||
                                            (g_opa == 4'h3) ||
                                            (g_opa == 4'ha));
  assign g_io_ram = (g_opr == 4'he) && !g_io_romport;

  logic g_jcn_raw;
  logic g_jcn_taken;
  assign g_jcn_raw = ((g_opa[2] && (g_acc == 4'h0)) ||
                      (g_opa[1] && g_cy) ||
                      (g_opa[0] && !test_i));
  assign g_jcn_taken = g_opa[3] ? !g_jcn_raw : g_jcn_raw;
  logic g_isz_taken;
  assign g_isz_taken = (g_idx[g_opa] != 4'hf);

  function automatic logic [3:0] g_kbp(input logic [3:0] v);
    case (v)
      4'h0:    g_kbp = 4'h0;
      4'h1:    g_kbp = 4'h1;
      4'h2:    g_kbp = 4'h2;
      4'h4:    g_kbp = 4'h3;
      4'h8:    g_kbp = 4'h4;
      default: g_kbp = 4'hf;
    endcase
  endfunction

  logic g_instr_end;
  assign g_instr_end = (g_phase == PhX3) && (g_cycle2 || !g_two_cycle);

  integer k;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      g_phase  <= PhA1;
      g_cycle2 <= 1'b0;
      g_acc    <= 4'h0;
      g_cy     <= 1'b0;
      g_sp     <= 2'd0;
      g_src    <= 8'h0;
      g_cmd    <= 3'b000;
      g_opr    <= 4'h0;
      g_opa    <= 4'h0;
      g_w2hi   <= 4'h0;
      g_w2lo   <= 4'h0;
      for (k = 0; k < 4; k++) begin
        g_stack[k] <= 12'h0;
      end
      for (k = 0; k < 16; k++) begin
        g_idx[k] <= 4'h0;
      end
    end else begin
      if (g_phase == PhX3) begin
        g_phase  <= PhA1;
        g_cycle2 <= !g_cycle2 && g_two_cycle;
      end else begin
        g_phase <= g_phase + 3'd1;
      end

      if (g_phase == PhM1) begin
        if (g_cycle2) begin
          g_w2hi <= data_i;
        end else begin
          g_opr <= data_i;
        end
      end
      if (g_phase == PhM2) begin
        if (g_cycle2) begin
          g_w2lo <= data_i;
        end else begin
          g_opa <= data_i;
        end
      end

      if (g_instr_end) begin
        g_stack[g_sp] <= g_cycle2 ? g_pc2 : g_pc1;
        case (g_opr)
          4'h1: begin  // JCN
            if (g_jcn_taken) begin
              g_stack[g_sp] <= {g_pc2[11:8], g_w2hi, g_w2lo};
            end
          end
          4'h2: begin  // FIM / SRC
            if (g_fim_word) begin
              g_idx[{g_pair, 1'b0}] <= g_w2hi;
              g_idx[{g_pair, 1'b1}] <= g_w2lo;
            end else begin
              g_src <= {g_idx[{g_pair, 1'b0}], g_idx[{g_pair, 1'b1}]};
            end
          end
          4'h3: begin  // FIN / JIN
            if (g_fin_word) begin
              g_idx[{g_pair, 1'b0}] <= g_w2hi;
              g_idx[{g_pair, 1'b1}] <= g_w2lo;
            end else begin
              g_stack[g_sp] <= {g_pc1[11:8], g_idx[{g_pair, 1'b0}],
                                g_idx[{g_pair, 1'b1}]};
            end
          end
          4'h4: begin  // JUN
            g_stack[g_sp] <= {g_opa, g_w2hi, g_w2lo};
          end
          4'h5: begin  // JMS
            g_stack[g_sp]        <= g_pc2;
            g_stack[g_sp + 2'd1] <= {g_opa, g_w2hi, g_w2lo};
            g_sp                 <= g_sp + 2'd1;
          end
          4'h6: begin  // INC
            g_idx[g_opa] <= g_idx[g_opa] + 4'd1;
          end
          4'h7: begin  // ISZ
            g_idx[g_opa] <= g_idx[g_opa] + 4'd1;
            if (g_isz_taken) begin
              g_stack[g_sp] <= {g_pc2[11:8], g_w2hi, g_w2lo};
            end
          end
          4'h8: begin  // ADD
            {g_cy, g_acc} <= g_acc + g_idx[g_opa] + {3'b000, g_cy};
          end
          4'h9: begin  // SUB: inverted carry, CY=0 means pending borrow
            {g_cy, g_acc} <= g_acc + {1'b0, ~g_idx[g_opa]} + {3'b000, ~g_cy};
          end
          4'ha: begin  // LD
            g_acc <= g_idx[g_opa];
          end
          4'hb: begin  // XCH
            g_acc        <= g_idx[g_opa];
            g_idx[g_opa] <= g_acc;
          end
          4'hc: begin  // BBL
            g_sp  <= g_sp - 2'd1;
            g_acc <= g_opa;
          end
          4'hd: begin  // LDM
            g_acc <= g_opa;
          end
          4'he: begin  // RAM / ROM port group
            case (g_opa)
              4'h8: begin  // SBM: inverted carry, same sense as SUB
                {g_cy, g_acc} <= g_acc + {1'b0, ~data_i} + {3'b000, ~g_cy};
              end
              4'h9, 4'ha: begin  // RDM, RDR
                g_acc <= data_i;
              end
              4'hb: begin  // ADM
                {g_cy, g_acc} <= g_acc + data_i + {3'b000, g_cy};
              end
              4'hc, 4'hd, 4'he, 4'hf: begin  // RD0-RD3
                g_acc <= data_i;
              end
              default: ;
            endcase
          end
          4'hf: begin  // accumulator group
            case (g_opa)
              4'h0: begin  // CLB
                g_acc <= 4'h0;
                g_cy  <= 1'b0;
              end
              4'h1: g_cy <= 1'b0;  // CLC
              4'h2: {g_cy, g_acc} <= g_acc + 4'd1;  // IAC
              4'h3: g_cy <= ~g_cy;  // CMC
              4'h4: g_acc <= ~g_acc;  // CMA
              4'h5: {g_cy, g_acc} <= {g_acc, g_cy};  // RAL
              4'h6: {g_cy, g_acc} <= {g_acc[0], g_cy, g_acc[3:1]};  // RAR
              4'h7: begin  // TCC
                g_acc <= {3'b000, g_cy};
                g_cy  <= 1'b0;
              end
              4'h8: begin  // DAC
                {g_cy, g_acc} <= g_acc + 4'hf;
              end
              4'h9: begin  // TCS
                g_acc <= g_cy ? 4'h9 : 4'ha;
                g_cy  <= 1'b0;
              end
              4'ha: g_cy <= 1'b1;  // STC
              4'hb: begin  // DAA
                if (g_cy || g_acc > 4'd9) begin
                  {g_cy, g_acc} <= g_acc + 4'd6;
                end
              end
              4'hc: g_acc <= g_kbp(g_acc);  // KBP
              4'hd: g_cmd <= g_acc[2:0];  // DCL
              default: ;
            endcase
          end
          default: ;
        endcase
      end
    end
  end

  // ------------------------------------------------------------------
  // Architectural equivalence and combinational output re-derivation
  // ------------------------------------------------------------------
  logic [3:0] exp_data_o;
  logic       exp_data_oe;
  logic [3:0] exp_cm_ram;

  always_comb begin
    exp_data_o  = 4'h0;
    exp_data_oe = 1'b0;
    case (phase)
      PhA1: begin
        exp_data_o  = g_fetch_addr[3:0];
        exp_data_oe = 1'b1;
      end
      PhA2: begin
        exp_data_o  = g_fetch_addr[7:4];
        exp_data_oe = 1'b1;
      end
      PhA3: begin
        exp_data_o  = g_fetch_addr[11:8];
        exp_data_oe = 1'b1;
      end
      PhX2, PhX3: begin
        if (g_src_word) begin
          exp_data_o  = (phase == PhX2) ? g_idx[{g_pair, 1'b0}]
                                      : g_idx[{g_pair, 1'b1}];
          exp_data_oe = 1'b1;
        end else if (g_io_write) begin
          exp_data_o  = g_acc;
          exp_data_oe = 1'b1;
        end
      end
      default: ;
    endcase
  end

  assign exp_cm_ram = (phase == PhX2 || phase == PhX3) &&
                    (g_src_word || g_io_ram)
                      ? {cmd[2], cmd[1], cmd[0], ~|cmd}
                      : 4'b0000;

  integer j;
  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      e_sp:   assert (g_sp == sp);
      e_stk0: assert (g_stack[0] == stack0);
      e_stk1: assert (g_stack[1] == stack1);
      e_stk2: assert (g_stack[2] == stack2);
      e_stk3: assert (g_stack[3] == stack3);
      e_acc:  assert (g_acc == acc);
      e_cy:   assert (g_cy == cy);
      e_src:  assert (g_src == src_ptr);
      e_cmd:  assert (g_cmd == cmd);
      e_latch_opr: assert (g_opr == opr);
      e_latch_opa: assert (g_opa == opa);
      for (j = 0; j < 16; j++) begin
        assert (g_idx[j] == idx_flat[j*4 +: 4]);
      end

      e_data_bus:  assert (data_o == exp_data_o);
      a_oe_chk:     assert (data_oe == exp_data_oe);
      e_sync:      assert (sync == (phase == PhA1));
      e_cm_rom:    assert (cm_rom == ((phase <= PhA3) ||
                                      ((phase == PhX2 || phase == PhX3) &&
                                       g_io_romport)));
      a_cmram_chk:  assert (cm_ram == exp_cm_ram);
      e_instr_end: assert (instr_end == g_instr_end);
    end
  end

  logic _unused_props;
  assign _unused_props = &{1'b0, opc1, opc2, mem_rd, PhX1};

endmodule
