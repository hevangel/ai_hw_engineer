`timescale 1ns/1ps

// Self-checking testbench for the Intel 4004 reconstruction. The bench is a
// small MCS-4 microsystem: behavioral 4001 ROM (with I/O ports and a WPM
// program-memory shadow) and 4002 RAM models respond on the multiplexed
// 4-bit bus exactly per spec/spec.md section 6, while an independent
// instruction-set simulator with its own shadow memories steps one
// instruction per commit. Architectural state is compared at every
// instruction boundary, bus behavior at every clock, and model memories at
// the end of each phase. A directed program exercises all 46 instructions
// including the page-straddle quirks, and a fixed-seed random program
// stresses the 1-word instruction set. The memory models decode the current
// opcode by snooping the fetch bus (a behavioral-model choice; the real
// chips qualify the command lines instead), and, like the ISS, select the
// lowest-numbered active RAM bank when a DCL combination enables several.
// CPU reset does not clear the RAM models (the 4002 has its own reset pin,
// not driven here); program ROM persists by design.
module tb_intel_4004;

  logic       clk;
  logic       rst_n = 1'b0;
  logic       test_i = 1'b1;
  logic [3:0] data_i;
  logic [3:0] data_o;
  logic       data_oe;
  logic       sync;
  logic       cm_rom;
  logic [3:0] cm_ram;

  initial begin
    clk = 1'b0;
  end
  always #5 clk = ~clk;

  intel_4004 dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .test_i (test_i),
      .data_i (data_i),
      .data_o (data_o),
      .data_oe(data_oe),
      .sync   (sync),
      .cm_rom (cm_rom),
      .cm_ram (cm_ram)
  );

  // ------------------------------------------------------------------
  // Counters and result tracking
  // ------------------------------------------------------------------
  integer cycle_count;
  integer boundary_count;
  integer phase_a_boundaries;
  integer phase_b_boundaries;
  integer failure_count;

  // One bit per defined instruction (0-45); 46 = undefined encodings
  logic [46:0] exec_seen;
  integer      exec_count_a;

  function automatic integer instr_id(input logic [7:0] w);
    case (w[7:4])
      4'h0:    instr_id = 0;
      4'h1:    instr_id = 1;
      4'h2:    instr_id = w[0] ? 3 : 2;
      4'h3:    instr_id = w[0] ? 5 : 4;
      4'h4:    instr_id = 6;
      4'h5:    instr_id = 7;
      4'h6:    instr_id = 8;
      4'h7:    instr_id = 9;
      4'h8:    instr_id = 10;
      4'h9:    instr_id = 11;
      4'ha:    instr_id = 12;
      4'hb:    instr_id = 13;
      4'hc:    instr_id = 14;
      4'hd:    instr_id = 15;
      4'he:    instr_id = 16 + {28'd0, w[3:0]};
      4'hf:    instr_id = (w[3:0] <= 4'hd) ? 32 + {28'd0, w[3:0]} : 46;
      default: instr_id = 46;
    endcase
  endfunction

  // ------------------------------------------------------------------
  // Independent phase counter and bus capture (pre-edge values)
  // ------------------------------------------------------------------
  logic [2:0] tb_phase;

  always_ff @(posedge clk) begin
    if (!rst_n)       tb_phase <= 3'd0;
    else if (sync)    tb_phase <= 3'd1;
    else              tb_phase <= tb_phase + 3'd1;
  end

  logic [2:0] cap_phase;
  logic       cap_sync, cap_oe, cap_cm_rom;
  logic [3:0] cap_data_o, cap_cm_ram, cap_data_i;

  always_ff @(posedge clk) begin
    cap_phase  <= tb_phase;
    cap_sync   <= sync;
    cap_oe     <= data_oe;
    cap_data_o <= data_o;
    cap_cm_rom <= cm_rom;
    cap_cm_ram <= cm_ram;
    cap_data_i <= data_i;
  end

  // ------------------------------------------------------------------
  // Model-side instruction tracking (decoded from the fetch bus)
  // ------------------------------------------------------------------
  logic [3:0] m_opr, m_opa;
  logic       m_cycle2;
  logic [7:0] m_srcptr;
  logic [3:0] m_bank;

  logic m_two, m_src, m_io;
  assign m_two = (m_opr == 4'h1) || (m_opr == 4'h4) || (m_opr == 4'h5) ||
                 (m_opr == 4'h7) || ((m_opr == 4'h2) && !m_opa[0]) ||
                 ((m_opr == 4'h3) && !m_opa[0]);
  assign m_src = (m_opr == 4'h2) && m_opa[0];
  assign m_io  = (m_opr == 4'he);

  logic [3:0] bank_of;
  assign bank_of = cap_cm_ram[0] ? 4'd0 :
                   cap_cm_ram[1] ? 4'd1 :
                   cap_cm_ram[2] ? 4'd2 : 4'd3;

  // Memory-side address wires
  logic [9:0] main_addr;
  assign main_addr = {m_bank[1:0], m_srcptr[7:6], m_srcptr[5:4],
                      m_srcptr[3:0]};
  logic [7:0] stat_addr;
  assign stat_addr = {m_bank[1:0], m_srcptr[7:6], m_srcptr[5:4], m_opa[1:0]};
  logic [3:0] oport_addr;
  assign oport_addr = {m_bank[1:0], m_srcptr[7:6]};

  // ------------------------------------------------------------------
  // 4001 ROM model: 4K x 8 program, I/O port per chip, WPM shadow
  // ------------------------------------------------------------------
  logic [7:0]  rom [4096];
  logic [11:0] rom_addr;
  logic [3:0]  rom_port_q [16];
  logic [3:0]  wpm_mem [16];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rom_addr <= 12'h0;
    end else begin
      if (cap_phase == 3'd0) rom_addr[3:0]  <= cap_data_o;
      if (cap_phase == 3'd1) rom_addr[7:4]  <= cap_data_o;
      if (cap_phase == 3'd2) rom_addr[11:8] <= cap_data_o;
    end
  end

  // ------------------------------------------------------------------
  // 4002 RAM model: main memory, status characters, output ports
  // ------------------------------------------------------------------
  logic [3:0] ram_main  [1024];
  logic [3:0] ram_stat  [256];
  logic [3:0] ram_oport [16];

  // (RAM model writes are applied in the checker block below.)

  // Bus read multiplexing: ROM fetch at M1/M2, memory reads at X3
  always_comb begin
    data_i = 4'h0;
    if (tb_phase == 3'd3) begin
      data_i = rom[rom_addr][7:4];
    end else if (tb_phase == 3'd4) begin
      data_i = rom[rom_addr][3:0];
    end else if (tb_phase == 3'd7 && m_io) begin
      case (m_opa)
        4'h8, 4'h9, 4'hb: data_i = ram_main[main_addr];  // SBM/RDM/ADM
        4'ha:             data_i = rom_port_q[m_srcptr[7:4]];
        4'hc, 4'hd, 4'he, 4'hf: data_i = ram_stat[stat_addr];
        default: ;
      endcase
    end
  end

  // ------------------------------------------------------------------
  // Instruction-set simulator (independent reference model)
  // ------------------------------------------------------------------
  logic [11:0] iss_stack [4];
  logic [1:0]  iss_sp;
  logic [11:0] iss_pc;
  logic [3:0]  iss_acc;
  logic        iss_cy;
  logic [3:0]  iss_idx [16];
  logic [7:0]  iss_srcptr;
  logic [2:0]  iss_cmd;
  logic [1:0]  iss_bank;
  logic [3:0]  iss_opr, iss_opa;
  logic [7:0]  iss_w2;
  logic        iss_cycle2;
  logic [3:0]  iss_ram_main  [1024];
  logic [3:0]  iss_ram_stat  [256];
  logic [3:0]  iss_ram_oport [16];
  logic [3:0]  iss_rom_port  [16];
  logic [3:0]  iss_wpm       [16];
  logic [7:0]  iss_last_w1;
  logic        iss_c2_prev;  // iss_cycle2 as of the committing edge

  logic iss_two, iss_src, iss_io, iss_fin;
  assign iss_two = (iss_opr == 4'h1) || (iss_opr == 4'h4) || (iss_opr == 4'h5) ||
                   (iss_opr == 4'h7) ||
                   ((iss_opr == 4'h2) && !iss_opa[0]) ||
                   ((iss_opr == 4'h3) && !iss_opa[0]);
  assign iss_src = (iss_opr == 4'h2) && iss_opa[0];
  assign iss_io  = (iss_opr == 4'he);
  assign iss_fin = (iss_opr == 4'h3) && !iss_opa[0];

  logic iss_commit;
  always_ff @(posedge clk) begin
    if (!rst_n) iss_commit <= 1'b0;
    else iss_commit <= (tb_phase == 3'd7) && (iss_cycle2 || !iss_two);
  end

  // (ISS fetch latches are applied in the checker block below.)

  logic [11:0] iss_pc1;
  assign iss_pc  = iss_stack[iss_sp];
  assign iss_pc1 = iss_pc + 12'd1;

  function automatic logic [3:0] iss_kbp(input logic [3:0] v);
    case (v)
      4'h0:    iss_kbp = 4'h0;
      4'h1:    iss_kbp = 4'h1;
      4'h2:    iss_kbp = 4'h2;
      4'h4:    iss_kbp = 4'h3;
      4'h8:    iss_kbp = 4'h4;
      default: iss_kbp = 4'hf;
    endcase
  endfunction

  function automatic logic [3:0] cm_decode(input logic [2:0] c);
    // line 0 when no bits set, lines 1..3 follow cmd bits 0..2 (spec 5.3)
    cm_decode = {c[2], c[1], c[0], ~|c};
  endfunction

  function automatic logic [9:0] iss_main_addr;
    iss_main_addr = {iss_bank[1:0], iss_srcptr[7:6], iss_srcptr[5:4],
                     iss_srcptr[3:0]};
  endfunction
  function automatic logic [7:0] iss_stat_addr(input logic [1:0] n);
    iss_stat_addr = {iss_bank[1:0], iss_srcptr[7:6], iss_srcptr[5:4], n};
  endfunction
  function automatic logic [3:0] iss_oport_addr;
    iss_oport_addr = {iss_bank[1:0], iss_srcptr[7:6]};
  endfunction

  task automatic iss_reset;
    integer mi;
    begin
      iss_sp     <= 2'd0;
      iss_acc    <= 4'h0;
      iss_cy     <= 1'b0;
      iss_srcptr <= 8'h0;
      iss_cmd    <= 3'b000;
      iss_bank   <= 2'd0;
      for (mi = 0; mi < 4; mi++) iss_stack[mi] = 12'h0;
      for (mi = 0; mi < 16; mi++) iss_idx[mi] = 4'h0;
    end
  endtask

  // Architectural step at an instruction commit (blocking, called at #1)
  task automatic iss_step;
    logic [11:0] pc1, pc2;
    logic [4:0]  sum;
    logic [3:0]  tmp;
    logic        jraw;
    begin
      iss_last_w1 = {iss_opr, iss_opa};
      pc1 = iss_pc + 12'd1;
      pc2 = iss_pc + 12'd2;
      iss_stack[iss_sp] = iss_c2_prev ? pc2 : pc1;
      case (iss_opr)
        4'h1: begin  // JCN
          jraw = ((iss_opa[2] && (iss_acc == 4'h0)) ||
                  (iss_opa[1] && iss_cy) ||
                  (iss_opa[0] && !test_i));
          if (iss_opa[3] ? !jraw : jraw) begin
            iss_stack[iss_sp] = {pc2[11:8], iss_w2};
          end
        end
        4'h2: begin
          if (!iss_opa[0]) begin  // FIM
            iss_idx[{iss_opa[3:1], 1'b0}] = iss_w2[7:4];
            iss_idx[{iss_opa[3:1], 1'b1}] = iss_w2[3:0];
          end else begin  // SRC
            iss_srcptr = {iss_idx[{iss_opa[3:1], 1'b0}],
                          iss_idx[{iss_opa[3:1], 1'b1}]};
            iss_bank = (iss_cmd == 3'b000) ? 2'd0 :
                       iss_cmd[0] ? 2'd1 :
                       iss_cmd[1] ? 2'd2 : 2'd3;
          end
        end
        4'h3: begin
          if (!iss_opa[0]) begin  // FIN
            iss_idx[{iss_opa[3:1], 1'b0}] = iss_w2[7:4];
            iss_idx[{iss_opa[3:1], 1'b1}] = iss_w2[3:0];
          end else begin  // JIN
            iss_stack[iss_sp] = {pc1[11:8], iss_idx[{iss_opa[3:1], 1'b0}],
                                 iss_idx[{iss_opa[3:1], 1'b1}]};
          end
        end
        4'h4: iss_stack[iss_sp] = {iss_opa, iss_w2};  // JUN
        4'h5: begin  // JMS
          iss_stack[iss_sp]        = pc2;
          iss_stack[iss_sp + 2'd1] = {iss_opa, iss_w2};
          iss_sp = iss_sp + 2'd1;
        end
        4'h6: iss_idx[iss_opa] = iss_idx[iss_opa] + 4'd1;  // INC
        4'h7: begin  // ISZ
          iss_idx[iss_opa] = iss_idx[iss_opa] + 4'd1;
          if (iss_idx[iss_opa] != 4'h0) begin
            iss_stack[iss_sp] = {pc2[11:8], iss_w2};
          end
        end
        4'h8: begin  // ADD
          sum = iss_acc + iss_idx[iss_opa] + {3'b000, iss_cy};
          {iss_cy, iss_acc} = sum;
        end
        4'h9: begin  // SUB (inverted carry: CY=0 = pending borrow)
          sum = iss_acc + {1'b0, ~iss_idx[iss_opa]} + {3'b000, ~iss_cy};
          {iss_cy, iss_acc} = sum;
        end
        4'ha: iss_acc = iss_idx[iss_opa];  // LD
        4'hb: begin  // XCH
          tmp = iss_acc;
          iss_acc = iss_idx[iss_opa];
          iss_idx[iss_opa] = tmp;
        end
        4'hc: begin  // BBL
          iss_sp = iss_sp - 2'd1;
          iss_acc = iss_opa;
        end
        4'hd: iss_acc = iss_opa;  // LDM
        4'he: begin
          case (iss_opa)
            4'h0: iss_ram_main[iss_main_addr()] = iss_acc;  // WRM
            4'h1: iss_ram_oport[iss_oport_addr()] = iss_acc;  // WMP
            4'h2: iss_rom_port[iss_srcptr[7:4]] = iss_acc;  // WRR
            4'h3: iss_wpm[iss_srcptr[7:4]] = iss_acc;  // WPM
            4'h4, 4'h5, 4'h6, 4'h7:
              iss_ram_stat[iss_stat_addr(iss_opa[1:0])] = iss_acc;
            4'h8: begin  // SBM (inverted carry)
              sum = iss_acc + {1'b0, ~iss_ram_main[iss_main_addr()]} +
                    {3'b000, ~iss_cy};
              {iss_cy, iss_acc} = sum;
            end
            4'h9, 4'ha: iss_acc = (iss_opa == 4'h9) ?
                iss_ram_main[iss_main_addr()] :
                iss_rom_port[iss_srcptr[7:4]];  // RDM / RDR
            4'hb: begin  // ADM
              sum = iss_acc + iss_ram_main[iss_main_addr()] +
                    {3'b000, iss_cy};
              {iss_cy, iss_acc} = sum;
            end
            4'hc, 4'hd, 4'he, 4'hf:
              iss_acc = iss_ram_stat[iss_stat_addr(iss_opa[1:0])];
            default: ;
          endcase
        end
        4'hf: begin
          case (iss_opa)
            4'h0: begin
              iss_acc = 4'h0;
              iss_cy = 1'b0;
            end
            4'h1: iss_cy = 1'b0;
            4'h2: begin
              sum = iss_acc + 4'd1;
              {iss_cy, iss_acc} = sum;
            end
            4'h3: iss_cy = ~iss_cy;
            4'h4: iss_acc = ~iss_acc;
            4'h5: {iss_cy, iss_acc} = {iss_acc, iss_cy};  // RAL
            4'h6: {iss_cy, iss_acc} = {iss_acc[0], iss_cy, iss_acc[3:1]};  // RAR
            4'h7: begin  // TCC
              iss_acc = {3'b000, iss_cy};
              iss_cy = 1'b0;
            end
            4'h8: begin  // DAC
              sum = iss_acc + 4'hf;
              {iss_cy, iss_acc} = sum;
            end
            4'h9: begin  // TCS
              iss_acc = iss_cy ? 4'h9 : 4'ha;
              iss_cy = 1'b0;
            end
            4'ha: iss_cy = 1'b1;  // STC
            4'hb: begin  // DAA
              if (iss_cy || iss_acc > 4'd9) begin
                sum = iss_acc + 4'd6;
                {iss_cy, iss_acc} = sum;
              end
            end
            4'hc: iss_acc = iss_kbp(iss_acc);  // KBP
            4'hd: iss_cmd = iss_acc[2:0];  // DCL
            default: ;
          endcase
        end
        default: ;
      endcase
    end
  endtask

  // ------------------------------------------------------------------
  // Per-cycle bus checks and per-boundary state comparison
  // ------------------------------------------------------------------
  logic [11:0] exp_addr;
  logic        exp_oe;
  logic        exp_cm_rom;
  logic [3:0]  exp_cm_ram;
  logic [3:0]  exp_data;

  logic [63:0] dut_idx_flat;
  logic [63:0] iss_idx_flat;

  // Blocking assignments in this checker are deliberate: it runs #1 after
  // each clock edge in simulation time order, not as synthesized logic.
  /* verilator lint_off BLKSEQ */
  always @(posedge clk) begin
    #1;
    if (!rst_n) begin
      iss_reset();
      iss_opr    = 4'h0;
      iss_opa    = 4'h0;
      iss_w2     = 8'h0;
      iss_cycle2 = 1'b0;
      m_opr      = 4'h0;
      m_opa      = 4'h0;
      m_cycle2   = 1'b0;
      m_srcptr   = 8'h0;
      m_bank     = 4'd0;
    end else begin
      // Apply every model-side update for the clock period that just ended
      // (cap_* hold the bus values during that period), so the models, the
      // reference-model fetch, and the commit all see the same edge.
      if (cap_phase == 3'd3 && !m_cycle2) m_opr = cap_data_i;
      if (cap_phase == 3'd4 && !m_cycle2) m_opa = cap_data_i;
      if (cap_phase == 3'd6 && m_src) m_srcptr[7:4] = cap_data_o;
      if (cap_phase == 3'd7 && m_src) begin
        m_srcptr[3:0] = cap_data_o;
        m_bank        = bank_of;
      end
      if (cap_phase == 3'd7) m_cycle2 = !m_cycle2 && m_two;

      // ROM model: WRR port write and WPM program-memory write at end of X3
      if (cap_phase == 3'd7 && m_io && m_opa == 4'h2)
        rom_port_q[m_srcptr[7:4]] = cap_data_o;
      if (cap_phase == 3'd7 && m_io && m_opa == 4'h3)
        wpm_mem[m_srcptr[7:4]] = cap_data_o;
      // RAM model: main/output-port/status writes at end of X3
      if (cap_phase == 3'd7 && m_io && m_opa == 4'h0)
        ram_main[main_addr] = cap_data_o;
      if (cap_phase == 3'd7 && m_io && m_opa == 4'h1)
        ram_oport[oport_addr] = cap_data_o;
      if (cap_phase == 3'd7 && m_io && m_opa >= 4'h4 && m_opa <= 4'h7)
        ram_stat[stat_addr] = cap_data_o;
      // ISS fetch latches
      if (cap_phase == 3'd3) begin
        if (iss_cycle2) iss_w2[7:4] = cap_data_i;
        else            iss_opr     = cap_data_i;
      end
      if (cap_phase == 3'd4) begin
        if (iss_cycle2) iss_w2[3:0] = cap_data_i;
        else            iss_opa     = cap_data_i;
      end
      iss_c2_prev = iss_cycle2;
      if (cap_phase == 3'd7) iss_cycle2 = !iss_cycle2 && iss_two;

      // Expected bus behavior for the period that just ended, from the ISS
      // state before stepping.
      exp_addr = iss_cycle2 ?
                   (iss_fin ? {iss_pc1[11:8], iss_idx[0], iss_idx[1]} : iss_pc1)
                   : iss_pc;
      exp_oe = (cap_phase <= 3'd2);
      exp_cm_rom = (cap_phase <= 3'd2);
      exp_cm_ram = 4'b0000;
      exp_data = exp_addr[cap_phase*4 +: 4];
      if (cap_phase >= 3'd6) begin
        if (iss_src) begin
          exp_oe = 1'b1;
          exp_data = (cap_phase == 3'd6) ?
                       iss_idx[{iss_opa[3:1], 1'b0}] :
                       iss_idx[{iss_opa[3:1], 1'b1}];
          exp_cm_ram = cm_decode(iss_cmd);
        end else if (iss_io) begin
          exp_cm_rom = (iss_opa == 4'h2) || (iss_opa == 4'h3) ||
                       (iss_opa == 4'ha);
          if (iss_opa <= 4'h7) begin
            exp_oe = 1'b1;
            exp_data = iss_acc;
            if (iss_opa != 4'h2 && iss_opa != 4'h3) begin
              exp_cm_ram = cm_decode(iss_cmd);
            end
          end else if (iss_opa >= 4'h8 && iss_opa != 4'ha) begin
            exp_cm_ram = cm_decode(iss_cmd);
          end
        end
      end

      // Step the reference model first (boundary compares use post-state)
      if (iss_commit) begin
        iss_step();
        boundary_count = boundary_count + 1;
        exec_seen[instr_id(iss_last_w1)] = 1'b1;
      end

      cycle_count = cycle_count + 1;
      if (boundary_count == 42 || boundary_count == 43) begin
        $display("CYC t=%0t b=%0d ph=%0d cmr=%b cmd=%h m_src=%b m_bank=%0d oe=%b",
                 $time, boundary_count, tb_phase, cm_ram, dut.cmd, m_src,
                 m_bank, data_oe);
      end
      if (cap_sync !== (cap_phase == 3'd0)) begin
        failure_count = failure_count + 1;
        $display("FAIL sync: phase=%0d sync=%b", cap_phase, cap_sync);
      end
      if (cap_oe !== exp_oe) begin
        failure_count = failure_count + 1;
        $display("FAIL data_oe: phase=%0d got=%b exp=%b (iss_pc=%h)",
                 cap_phase, cap_oe, exp_oe, iss_pc);
      end
      if (exp_oe && (cap_data_o !== exp_data)) begin
        failure_count = failure_count + 1;
        $display("FAIL bus data: phase=%0d got=%h exp=%h (iss_pc=%h)",
                 cap_phase, cap_data_o, exp_data, iss_pc);
      end
      if (cap_cm_rom !== exp_cm_rom) begin
        failure_count = failure_count + 1;
        $display("FAIL cm_rom: phase=%0d got=%b exp=%b",
                 cap_phase, cap_cm_rom, exp_cm_rom);
      end
      if (cap_cm_ram !== exp_cm_ram) begin
        failure_count = failure_count + 1;
        $display("FAIL cm_ram: phase=%0d got=%b exp=%b (iss_pc=%h opa=%h)",
                 cap_phase, cap_cm_ram, exp_cm_ram, iss_pc, iss_opa);
      end

      // Boundary state comparison
      if (iss_commit) begin
        iss_idx_flat = {iss_idx[15], iss_idx[14], iss_idx[13], iss_idx[12],
                        iss_idx[11], iss_idx[10], iss_idx[9],  iss_idx[8],
                        iss_idx[7],  iss_idx[6],  iss_idx[5],  iss_idx[4],
                        iss_idx[3],  iss_idx[2],  iss_idx[1],  iss_idx[0]};
        dut_idx_flat = {dut.idx[15], dut.idx[14], dut.idx[13], dut.idx[12],
                        dut.idx[11], dut.idx[10], dut.idx[9],  dut.idx[8],
                        dut.idx[7],  dut.idx[6],  dut.idx[5],  dut.idx[4],
                        dut.idx[3],  dut.idx[2],  dut.idx[1],  dut.idx[0]};
        if (iss_sp !== dut.sp || iss_stack[0] !== dut.stack[0] ||
            iss_stack[1] !== dut.stack[1] || iss_stack[2] !== dut.stack[2] ||
            iss_stack[3] !== dut.stack[3]) begin
          failure_count = failure_count + 1;
          $display(
              "FAIL pc/stack @%0t: dut sp=%0d [%h %h %h %h] iss sp=%0d [%h %h %h %h] after w1=%h",
              $time, dut.sp, dut.stack[0], dut.stack[1], dut.stack[2],
              dut.stack[3], iss_sp, iss_stack[0], iss_stack[1], iss_stack[2],
              iss_stack[3], iss_last_w1);
        end
        if (iss_acc !== dut.acc || iss_cy !== dut.cy) begin
          failure_count = failure_count + 1;
          $display(
              "FAIL acc/cy @%0t: dut acc=%h cy=%b iss acc=%h cy=%b after w1=%h",
              $time, dut.acc, dut.cy, iss_acc, iss_cy, iss_last_w1);
        end
        if (iss_idx_flat !== dut_idx_flat) begin
          failure_count = failure_count + 1;
          $display("FAIL idx @%0t: dut=%h iss=%h after w1=%h", $time,
                   dut_idx_flat, iss_idx_flat, iss_last_w1);
        end
        if (iss_srcptr !== dut.src_ptr || iss_cmd !== dut.cmd) begin
          failure_count = failure_count + 1;
          $display("FAIL src/cmd @%0t: dut src=%h cmd=%h iss src=%h cmd=%h",
                   $time, dut.src_ptr, dut.cmd, iss_srcptr, iss_cmd);
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // Model memory comparison at phase ends
  // ------------------------------------------------------------------
  task automatic compare_memories;
    integer mi;
    begin
      for (mi = 0; mi < 1024; mi++) begin
        if (ram_main[mi] !== iss_ram_main[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL ram_main[%0d]: model=%h iss=%h", mi, ram_main[mi],
                   iss_ram_main[mi]);
        end
      end
      for (mi = 0; mi < 256; mi++) begin
        if (ram_stat[mi] !== iss_ram_stat[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL ram_stat[%0d]: model=%h iss=%h", mi, ram_stat[mi],
                   iss_ram_stat[mi]);
        end
      end
      for (mi = 0; mi < 64; mi++) begin
        if (ram_oport[mi] !== iss_ram_oport[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL ram_oport[%0d]: model=%h iss=%h", mi, ram_oport[mi],
                   iss_ram_oport[mi]);
        end
      end
      for (mi = 0; mi < 16; mi++) begin
        if (rom_port_q[mi] !== iss_rom_port[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL rom_port[%0d]: model=%h iss=%h", mi, rom_port_q[mi],
                   iss_rom_port[mi]);
        end
        if (wpm_mem[mi] !== iss_wpm[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL wpm_mem[%0d]: model=%h iss=%h", mi, wpm_mem[mi],
                   iss_wpm[mi]);
        end
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Program construction and main sequence
  // ------------------------------------------------------------------
  integer pw;
  integer park_addr;
  integer mi;
  logic [15:0] lfsr;
  logic [7:0]  rb;

  task automatic emit(input logic [7:0] b);
    begin
      rom[pw] = b;
      pw = pw + 1;
    end
  endtask

  function automatic logic [15:0] lfsr_next(input logic [15:0] l);
    lfsr_next = {l[14:0], l[15] ^ l[13] ^ l[12] ^ l[10]};
  endfunction

  initial begin
    cycle_count = 0;
    boundary_count = 0;
    phase_a_boundaries = 0;
    phase_b_boundaries = 0;
    failure_count = 0;
    exec_count_a = 0;
    exec_seen = '0;
    for (mi = 0; mi < 4096; mi++) rom[mi] = 8'h00;
    for (mi = 0; mi < 1024; mi++) begin
      ram_main[mi] = 4'h0;
      iss_ram_main[mi] = 4'h0;
    end
    for (mi = 0; mi < 256; mi++) begin
      ram_stat[mi] = 4'h0;
      iss_ram_stat[mi] = 4'h0;
    end
    for (mi = 0; mi < 16; mi++) begin
      ram_oport[mi] = 4'h0;
      iss_ram_oport[mi] = 4'h0;
    end
    for (mi = 0; mi < 16; mi++) begin
      rom_port_q[mi] = 4'h0;
      wpm_mem[mi] = 4'h0;
      iss_rom_port[mi] = 4'h0;
      iss_wpm[mi] = 4'h0;
    end

    // ---- Directed program (page 0, straddle zones in pages 1-2) ----
    pw = 0;
    emit(8'h00);        // NOP
    emit(8'hD5);        // LDM 5
    emit(8'hF2);        // IAC
    emit(8'hFB);        // DAA
    emit(8'hF5);        // RAL
    emit(8'hF6);        // RAR
    emit(8'hF4);        // CMA
    emit(8'hF8);        // DAC
    emit(8'hF9);        // TCS
    emit(8'hFA);        // STC
    emit(8'hF7);        // TCC
    emit(8'hF3);        // CMC
    emit(8'hF1);        // CLC
    emit(8'hF0);        // CLB
    emit(8'hFC);        // KBP
    emit(8'hD0);        // LDM 0
    emit(8'h20);        // FIM P0, 0x12 -> r0=1, r1=2
    emit(8'h12);
    emit(8'hA0);        // LD r0
    emit(8'h81);        // ADD r1
    emit(8'h91);        // SUB r1
    emit(8'hB0);        // XCH r0
    emit(8'h60);        // INC r0
    emit(8'h80);        // ADD r0
    emit(8'h90);        // SUB r0
    emit(8'hDF);        // LDM F
    emit(8'h61);        // INC r1
    emit(8'hF2);        // IAC -> wraps to 0 with carry
    emit(8'hFB);        // DAA with carry set
    emit(8'hF8);        // DAC
    // I/O: RAM chip 1, register 1, char 7 via pair 3 (pointer 0x47)
    emit(8'h26);        // FIM P3, 0x47
    emit(8'h47);
    emit(8'h27);        // SRC P3
    emit(8'hE0);        // WRM
    emit(8'hE9);        // RDM
    emit(8'hEB);        // ADM
    emit(8'hE8);        // SBM
    emit(8'hE4);        // WR0
    emit(8'hEC);        // RD0
    emit(8'hE5);        // WR1
    emit(8'hED);        // RD1
    emit(8'hE1);        // WMP
    emit(8'hD3);        // LDM 3
    emit(8'hFD);        // DCL (cmd=3: combined lines, bank decode -> line 1)
    emit(8'h27);        // SRC P3
    emit(8'hE0);        // WRM
    emit(8'hE9);        // RDM
    emit(8'hD7);        // LDM 7
    emit(8'hFD);        // DCL (cmd=7)
    emit(8'h27);        // SRC P3
    emit(8'hE0);        // WRM
    emit(8'hE9);        // RDM
    emit(8'hD1);        // LDM 1
    emit(8'hFD);        // DCL (cmd=1: bank 1)
    emit(8'h28);        // FIM P4, 0xB8 -> r8=B, r9=8
    emit(8'hB8);
    emit(8'h29);        // SRC P4
    emit(8'hE0);        // WRM
    emit(8'hE9);        // RDM
    emit(8'hE6);        // WR2
    emit(8'hEE);        // RD2
    emit(8'hE1);        // WMP
    emit(8'hD2);        // LDM 2
    emit(8'hFD);        // DCL (cmd=2: bank 2)
    emit(8'h29);        // SRC P4
    emit(8'hE0);        // WRM
    emit(8'hE9);        // RDM
    emit(8'hE7);        // WR3
    emit(8'hEF);        // RD3
    emit(8'hEB);        // ADM
    emit(8'hE8);        // SBM
    // ROM I/O ports: pair 5 = 0x5C -> rA=5, rC=C (ROM chip 5)
    emit(8'h2A);        // FIM P5, 0x5C
    emit(8'h5C);
    emit(8'h2B);        // SRC P5
    emit(8'hD9);        // LDM 9
    emit(8'hE2);        // WRR
    emit(8'hEA);        // RDR
    emit(8'hD3);        // LDM 3
    emit(8'hE2);        // WRR
    emit(8'hEA);        // RDR
    emit(8'hDA);        // LDM A
    emit(8'hE3);        // WPM
    // JCN: all 16 condition codes, target = fallthrough
    for (mi = 0; mi < 16; mi++) begin
      rom[pw] = 8'h10 | {4'b0000, mi[3:0]};
      rom[pw + 1] = pw[7:0] + 8'h02;
      pw = pw + 2;
    end
    // Control flow: JUN over a skipped word
    rom[pw] = 8'h40;
    rom[pw + 1] = pw[7:0] + 8'h03;
    pw = pw + 3;
    emit(8'hDF);        // skipped LDM F
    // JMS/BBL: 3-deep nesting
    rom[pw] = 8'h50;
    rom[pw + 1] = pw[7:0] + 8'h0A;  // JMS sub1 (sub1 = pw+10)
    pw = pw + 2;
    rom[pw] = 8'h40;    // R1: JUN done (done = pw+10)
    rom[pw + 1] = pw[7:0] + 8'h0A;
    pw = pw + 2;
    // sub1: JMS sub2; BBL A
    rom[pw] = 8'h50;
    rom[pw + 1] = pw[7:0] + 8'h08;  // sub2 = pw+8
    pw = pw + 2;
    emit(8'hCA);        // BBL A
    // sub2: JMS sub3; BBL B
    rom[pw] = 8'h50;
    rom[pw + 1] = pw[7:0] + 8'h06;  // sub3 = pw+6
    pw = pw + 2;
    emit(8'hCB);        // BBL B
    // sub3: LDM 7; BBL C
    emit(8'hD7);
    emit(8'hCC);        // BBL C
    // ISZ self-loop: counts rD 3,2,1 (taken), 0 (skip)
    emit(8'h2C);        // FIM P6, 0x03 -> rC=0, rD=3
    emit(8'h03);
    rom[pw] = 8'h7D;    // ISZ rD, self
    rom[pw + 1] = pw[7:0];
    pw = pw + 2;
    // ISZ skip path: rC = F wraps to 0
    emit(8'h2C);        // FIM P6, 0xF0 -> rC=F, rD=0
    emit(8'hF0);
    rom[pw] = 8'h7C;    // ISZ rC -> skip
    rom[pw + 1] = pw[7:0] + 8'h02;
    pw = pw + 3;
    emit(8'hD0);        // skipped LDM 0
    // FIN basic: pointer to an inline word, fetched then executed
    rom[pw] = 8'h20;    // FIM P0, DT
    rom[pw + 1] = pw[7:0] + 8'h06;  // DT = pw+6
    pw = pw + 2;
    emit(8'h34);        // FIN P2 -> r4/r5 = rom[DT]
    rom[pw] = 8'h40;    // JUN over DT
    rom[pw + 1] = pw[7:0] + 8'h03;
    pw = pw + 3;
    emit(8'hD7);        // DT (LDM 7 as data and instruction)
    // JIN: pair 0 points at the continuation word
    rom[pw] = 8'h20;    // FIM P0, L_jt
    rom[pw + 1] = pw[7:0] + 8'h04;
    pw = pw + 2;
    emit(8'h31);        // JIN P0 -> L_jt
    emit(8'hD7);        // L_jt: LDM 7
    // Tail: preload r0 = 1 and enter the straddle zone at 0x0FE
    emit(8'hD0);        // LDM 0
    emit(8'h60);        // INC r0 -> r0 = 1
    emit(8'h40);        // JUN 0x0FE
    emit(8'hFE);
    // Park: self-jump reached from the straddle-zone tail
    park_addr = pw;
    rom[pw] = 8'h40;    // JUN park (self)
    rom[pw + 1] = pw[7:0];
    pw = pw + 2;

    // ---- Fixed-address straddle zone ----
    rom[12'h0FE] = 8'h70;  // ISZ r0 (taken: 1->2), w2 at 0x0FF
    rom[12'h0FF] = 8'h04;  // target {page(0x100), 04} = 0x104 (page roll!)
    rom[12'h100] = 8'h00;  // padding
    rom[12'h101] = 8'h00;
    rom[12'h102] = 8'h00;
    rom[12'h103] = 8'h00;
    rom[12'h104] = 8'h20;  // FIM P0, 0xFE -> r0=F, r1=E
    rom[12'h105] = 8'hFE;
    rom[12'h106] = 8'h36;  // FIN P3 -> r6/r7 = rom[0xFE] = 0x70
    rom[12'h107] = 8'h41;  // JUN 0x1F0
    rom[12'h108] = 8'hF0;
    rom[12'h1F0] = 8'h20;  // FIM P0, 0x10 -> r0=0, r1=0x10
    rom[12'h1F1] = 8'h10;
    for (mi = 32'h1F2; mi < 32'h1FF; mi++) rom[mi] = 8'h00;
    rom[12'h1FF] = 8'h38;  // FIN P4 at word 255: fetch {page(0x200), 0, 0x10}
    for (mi = 32'h200; mi < 32'h210; mi++) rom[mi] = 8'h00;  // landing NOPs
    rom[12'h210] = 8'h5A;  // marker word (r8=5, r9=A via FIN; SUB rA if run)
    rom[12'h211] = 8'h40;  // JUN park
    rom[12'h212] = park_addr[7:0];

    // ---- Random program (page 3, 1-word instructions only) ----
    lfsr = 16'hACE1;
    for (mi = 0; mi < 256; mi++) begin
      lfsr = lfsr_next(lfsr);
      rb = {lfsr[3:0], lfsr[7:4]};
      if (rb[7:4] == 4'h1 || rb[7:4] == 4'h4 || rb[7:4] == 4'h5 ||
          rb[7:4] == 4'h7) begin
        rb[7:4] = 4'h6;  // replace two-word opcodes with INC
      end
      rom[32'h300 + mi] = rb;
    end

    // ---- Run phase A: directed program ----
    $display("4004 tb: program A = %0d words, park = 0x%03h", pw, park_addr);
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    while (boundary_count < 12000 && failure_count == 0) @(posedge clk);
    phase_a_boundaries = boundary_count;
    for (mi = 0; mi < 46; mi++) begin
      if (exec_seen[mi]) exec_count_a = exec_count_a + 1;
    end
    compare_memories();

    // ---- Run phase B: reset, patch entry, run the random region ----
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rom[12'h000] = 8'h43;  // JUN 0x300 (random region)
    rom[12'h001] = 8'h00;
    rst_n = 1'b1;
    while (boundary_count < 12000 + 8192 && failure_count == 0)
      @(posedge clk);
    phase_b_boundaries = boundary_count - phase_a_boundaries;
    compare_memories();

    // ---- Report ----
    $display(
        "4004 simulation result: %0d cycles, %0d instruction boundaries",
        cycle_count, boundary_count);
    $display("Phase A boundaries: %0d (%0d/46 instructions seen), Phase B boundaries: %0d",
             phase_a_boundaries, exec_count_a, phase_b_boundaries);
    if (failure_count == 0) begin
      for (mi = 0; mi < 46; mi++) begin
        if (!exec_seen[mi]) begin
          failure_count = failure_count + 1;
          $display("FAIL: instruction id %0d never executed", mi);
        end
      end
    end
    if (failure_count == 0) begin
      $display("TEST PASSED");
    end else begin
      $display("TEST FAILED: %0d failures", failure_count);
    end
    $finish;
  end

  // Watchdog
  initial begin
    #60_000_000;
    $display("TEST FAILED: watchdog timeout at %0t", $time);
    $finish;
  end

  /* verilator lint_on BLKSEQ */

endmodule
