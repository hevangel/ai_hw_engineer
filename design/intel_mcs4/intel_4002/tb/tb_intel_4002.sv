`timescale 1ns/1ps

// Direct self-checking testbench for the Intel 4002 reconstruction (no UVM).
//
// A behavioral CPU-side bus master issues real 8-phase instruction cycles
// matching the repository's verified intel_4004 timing exactly: SYNC pulse at
// A1, instruction word broadcast at M1/M2, DCL-decoded CM-RAM bank lines
// during X2/X3 of SRC and RAM commands, SRC select code at X2 (chip+register)
// and X3 (character), write data at X2/X3, read data sampled at X2/X3.
//
// Two DUTs share one 4-bit bus, exactly like a two-bank MCS-4 system:
//   dut1: 4002-1 (Variant1=1), po=1 -> chip number 1, wired to CM-RAM line 0
//   dut2: 4002-2 (Variant1=0), po=0 -> chip number 2, wired to CM-RAM line 3
//
// An independently written golden model (arrays + decode from spec/spec.md)
// is scoreboarding every valid bus cycle (driven nibble on reads, undriven
// bus otherwise) and the output ports continuously; the model is updated for
// writes at each instruction boundary. Directed tests cover every command
// and corner; a fixed-seed LFSR phase adds randomized breadth.
module tb_intel_4002;

  logic clk;
  logic rst_n;
  logic sync;

  // Master (CPU) side of the bus
  logic [3:0]  m_o;
  logic        m_oe;
  logic [3:0]  cm_lines;   // decoded CM-RAM lines (one-hot), as the 4004

  // DUT sides
  logic [3:0] d1_o, d2_o;
  logic       d1_oe, d2_oe;
  logic [3:0] io1, io2;

  // Shared 4-bit bus with tri-state resolution
  logic _unused_cm;
  assign _unused_cm = cm_lines[2] ^ cm_lines[1];

  wire [3:0] bus = m_oe ? m_o :
                   d1_oe ? d1_o :
                   d2_oe ? d2_o : 4'bzzzz;

  intel_4002 #(.Variant1(1'b1)) dut1 (
      .clk      (clk),
      .rst_n    (rst_n),
      .data_i   (bus),
      .data_o   (d1_o),
      .data_oe  (d1_oe),
      .sync     (sync),
      .cm_ram_i (cm_lines[0]),
      .po_i     (1'b1),
      .io_o     (io1)
  );

  intel_4002 #(.Variant1(1'b0)) dut2 (
      .clk      (clk),
      .rst_n    (rst_n),
      .data_i   (bus),
      .data_o   (d2_o),
      .data_oe  (d2_oe),
      .sync     (sync),
      .cm_ram_i (cm_lines[3]),
      .po_i     (1'b0),
      .io_o     (io2)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // ------------------------------------------------------------------
  // Scoreboard bookkeeping
  // ------------------------------------------------------------------
  integer n_checks;
  integer n_fails;
  integer n_cycles;

  task automatic chk(input logic ok, input integer id);
    if (ok) begin
      n_checks = n_checks + 1;
    end else begin
      n_fails = n_fails + 1;
      $display("FAIL id=%0d at t=%0t", id, $time);
    end
  endtask

  // ------------------------------------------------------------------
  // Golden model (independent of the RTL expressions)
  //   gm_main[d*64 + {reg,char}]  main memory of DUT d
  //   gm_stat[d*16 + {reg,sc}]    status characters of DUT d
  //   gm_addr[d]                  SRC address register of DUT d
  //   gm_port[d]                  output port latch of DUT d
  // ------------------------------------------------------------------
  logic [3:0] gm_main  [0:127];
  logic [3:0] gm_stat  [0:31];
  logic [7:0] gm_addr  [0:1];
  logic [3:0] gm_port  [0:1];
  logic [2:0] dcl;         // CPU DCL command register (bank decode)

  function automatic logic bank_of_dut(input integer d);
    if (d == 0) begin
      bank_of_dut = (dcl == 3'b000);   // CM-RAM line 0
    end else begin
      bank_of_dut = dcl[2];            // CM-RAM line 3
    end
  endfunction

  function automatic logic [1:0] chip_of_dut(input integer d);
    chip_of_dut = (d == 0) ? 2'd1 : 2'd2;
  endfunction

  // Expected read nibble from DUT d's golden state
  function automatic logic [3:0] gsel(input integer d, input logic [3:0] opa);
    logic [6:0] gix;
    logic [4:0] six;
    begin
      gix = {1'b0, gm_addr[d][5:0]};
      six = {1'b0, gm_addr[d][5:4], opa[1:0]};
      if (d == 1) begin
        gix = gix + 7'd64;
        six = six + 5'd16;
      end
      if (opa == 4'h8 || opa == 4'h9 || opa == 4'hb) begin
        gsel = gm_main[gix];
      end else begin
        gsel = gm_stat[six];
      end
    end
  endfunction

  task automatic g_reset;
    integer i;
    begin
      dcl = 3'b000;
      gm_addr[0] = 8'h00;
      gm_addr[1] = 8'h00;
      gm_port[0] = 4'h0;
      gm_port[1] = 4'h0;
      for (i = 0; i < 128; i = i + 1) begin
        gm_main[i] = 4'h0;
      end
      for (i = 0; i < 32; i = i + 1) begin
        gm_stat[i] = 4'h0;
      end
    end
  endtask

  // ------------------------------------------------------------------
  // 8-phase cycle engine (drives on negedge, DUTs sample on posedge)
  //   drv:    master drives x2d/x3d during X2/X3 (SRC or write commands)
  //   cm_en:  assert the DCL-decoded CM-RAM lines during X2/X3
  // Checks during X2/X3: expected read nibble on the bus (or undriven),
  // output ports vs golden model, OE mutual exclusion.
  // ------------------------------------------------------------------
  logic        xp_valid;
  logic [3:0]  xp_val;
  logic        cm_en;
  logic        drv;

  task automatic t_cycle(
      input logic [3:0] opr,
      input logic [3:0] opa,
      input logic [3:0] x2d,
      input logic [3:0] x3d
  );
    integer p;
    begin
      n_cycles = n_cycles + 1;
      for (p = 0; p < 8; p = p + 1) begin
        @(negedge clk);
        case (p[2:0])
          3'd0: begin
            sync  = 1'b1;
            m_oe  = 1'b0;
            cm_lines = 4'b0000;
          end
          3'd1: begin
            sync = 1'b0;
          end
          3'd3: begin
            m_oe = 1'b1;
            m_o  = opr;
          end
          3'd4: begin
            m_oe = 1'b1;
            m_o  = opa;
          end
          3'd5: begin
            m_oe = 1'b0;
          end
          3'd6: begin
            m_oe     = drv;
            m_o      = x2d;
            cm_lines = cm_en ? {dcl[2], dcl[1], dcl[0], (dcl == 3'b000)}
                              : 4'b0000;
          end
          3'd7: begin
            m_oe = drv;
            m_o  = x3d;
          end
          default: ;
        endcase
        // NOTE: no cleanup of m_oe/cm_lines here — X3 values must stay
        // valid through the sampling posedge that ends this period; the
        // next cycle's p0 (or t_reset) clears them instead.
        #4;
        // Output ports hold their golden value at every phase
        if (io1 !== gm_port[0]) begin
          $display("DBG port1 got=%h exp=%h t=%0t", io1, gm_port[0], $time);
        end
        if (io2 !== gm_port[1]) begin
          $display("DBG port2 got=%h exp=%h t=%0t", io2, gm_port[1], $time);
        end
        chk (io1 === gm_port[0], 1);
        chk (io2 === gm_port[1], 2);
        if (p == 6 || p == 7) begin
          chk (!(d1_oe && d2_oe), 3);
          chk (!(m_oe && (d1_oe || d2_oe)), 4);
          if (!drv) begin
            if (xp_valid) begin
              if (bus !== xp_val) begin
                $display("DBG rd exp=%h got=%h cyc=%0d dcl=%h a0=%h a1=%h u1a=%h u2a=%h oe1=%b oe2=%b cm=%b ph=%0d o1=%h o2=%h m15=%h t=%0t",
                         xp_val, bus, n_cycles, dcl, gm_addr[0], gm_addr[1],
                         dut1.addr, dut2.addr, d1_oe, d2_oe, cm_lines,
                         dut1.phase, io1, io2, dut1.main_mem[15], $time);
              end
              chk (bus === xp_val, 5);
            end else begin
              chk (bus === 4'bzzzz, 6);
            end
          end
        end
      end
    end
  endtask

  // DCL: OPR=1111, OPA=1101; bank decode updates at the cycle boundary
  task automatic t_dcl(input logic [2:0] v);
    begin
      cm_en    = 1'b0;
      drv      = 1'b0;
      xp_valid = 1'b0;  // no expected drive during DCL; drop stale expectation
      t_cycle(4'hf, 4'hd, 4'h0, 4'h0);
      dcl = v;
    end
  endtask

  // SRC: pair content {chip, register} at X2, character at X3
  task automatic t_src(
      input logic [1:0] c,
      input logic [1:0] r,
      input logic [3:0] ch
  );
    begin
      cm_en = 1'b1;
      drv   = 1'b1;
      t_cycle(4'h2, {1'b0, r, 1'b1}, {c, r}, ch);
      if (bank_of_dut(0)) begin
        gm_addr[0] = {c, r, ch};
      end
      if (bank_of_dut(1)) begin
        gm_addr[1] = {c, r, ch};
      end
    end
  endtask

  // RAM I/O command (OPR=1110). Data written on the bus for write commands;
  // expected read drive computed from the golden model before the cycle.
  task automatic t_cmd(input logic [3:0] opa, input logic [3:0] wdata);
    logic romside, isread, iswrm, iswmp, iswrs;
    logic sel0, sel1;
    begin
      romside = (opa == 4'h2) || (opa == 4'h3) || (opa == 4'ha);
      isread  = opa[3] && !romside;
      iswrm   = (opa == 4'h0);
      iswmp   = (opa == 4'h1);
      iswrs   = (opa >= 4'h4) && (opa <= 4'h7);
      sel0    = bank_of_dut(0) && (gm_addr[0][7:6] == chip_of_dut(0));
      sel1    = bank_of_dut(1) && (gm_addr[1][7:6] == chip_of_dut(1));
      chk (!(sel0 && sel1), 7);

      xp_valid = 1'b0;
      xp_val   = 4'h0;
      if (isread && sel0) begin
        xp_valid = 1'b1;
        xp_val   = gsel(0, opa);
      end else if (isread && sel1) begin
        xp_valid = 1'b1;
        xp_val   = gsel(1, opa);
      end

      cm_en = !romside;
      drv   = !isread;
      t_cycle(4'he, opa, wdata, wdata);

      // Golden model commits writes at the end of X3
      if (iswrm) begin
        if (sel0) begin
          gm_main[{1'b0, gm_addr[0][5:0]}] = wdata;
        end
        if (sel1) begin
          gm_main[{1'b1, gm_addr[1][5:0]}] = wdata;
        end
      end
      if (iswmp) begin
        if (sel0) begin
          gm_port[0] = wdata;
        end
        if (sel1) begin
          gm_port[1] = wdata;
        end
      end
      if (iswrs) begin
        if (sel0) begin
          gm_stat[{1'b0, gm_addr[0][5:4], opa[1:0]}] = wdata;
        end
        if (sel1) begin
          gm_stat[{1'b1, gm_addr[1][5:4], opa[1:0]}] = wdata;
        end
      end
    end
  endtask

  // Advance past the commit posedge that ends the current instruction cycle
  // (t_cycle returns 1 ns before it), so post-cycle state checks see the
  // committed values. Leaves phase alignment intact: the next t_cycle waits
  // for the same p=0 negedge as before.
  task automatic t_settle;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  // ------------------------------------------------------------------
  // Fixed-seed LFSR for the randomized phase
  // ------------------------------------------------------------------
  logic [15:0] lfsr;
  function automatic logic [15:0] lfsr_next;
    begin
      lfsr_next = {lfsr[14:0],
                   lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
  endfunction

  // ------------------------------------------------------------------
  // Reset (chip + golden model + CPU-side DCL register)
  // ------------------------------------------------------------------
  task automatic t_reset;
    begin
      @(negedge clk);
      rst_n = 1'b0;
      sync  = 1'b0;
      m_oe  = 1'b0;
      cm_lines = 4'b0000;
      repeat (3) @(negedge clk);
      @(negedge clk);
      rst_n = 1'b1;
      g_reset();
      n_cycles = n_cycles + 4;
    end
  endtask

  // ------------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------------
  integer i, r, c;
  logic [3:0] v;
  logic [4:0] acc5;
  logic       tcy;
  logic [2:0] rops;
  logic [3:0] rops_opa;
  logic [1:0] rchip;
  logic [1:0] rreg;
  logic [3:0] rchar;
  logic [3:0] rdata;

  initial begin
    n_checks = 0;
    n_fails  = 0;
    n_cycles = 0;
    rst_n    = 1'b1;
    sync     = 1'b0;
    m_oe     = 1'b0;
    m_o      = 4'h0;
    cm_lines = 4'b0000;
    lfsr     = 16'hace1;
    g_reset();

    $display("=== TB intel_4002: reset ===");
    t_reset();

    // -- reset behavior: ports clear, no drive, memory reads 0
    chk (io1 === 4'h0, 100);
    chk (io2 === 4'h0, 101);
    t_src(2'd1, 2'd0, 4'h0);
    t_cmd(4'h9, 4'h0);          // RDM from cleared memory -> 0, driven
    t_cmd(4'hc, 4'h0);          // RD0 -> 0

    $display("=== TB intel_4002: main memory sweep, DUT1 (chip 1, bank 0) ===");
    for (r = 0; r < 4; r = r + 1) begin
      for (c = 0; c < 16; c = c + 1) begin
        v = ({r[1:0], c[1:0]} ^ {2'b00, c[1:0]}) + {2'b00, c[3:2]} + {2'b00, r[1:0]};
        t_src(2'd1, r[1:0], c[3:0]);
        t_cmd(4'h0, v);                       // WRM
      end
      for (c = 15; c >= 0; c = c - 1) begin
        t_src(2'd1, r[1:0], c[3:0]);
        t_cmd(4'h9, 4'h0);                    // RDM, expect written value
      end
    end

    $display("=== TB intel_4002: switch to bank 3 (DUT2, chip 2) ===");
    t_dcl(3'b100);
    for (r = 0; r < 4; r = r + 1) begin
      for (c = 0; c < 16; c = c + 1) begin
        t_src(2'd2, r[1:0], c[3:0]);
        t_cmd(4'h0, c[3:0] + {2'b00, r[1:0]});  // WRM into DUT2
      end
      for (c = 0; c < 16; c = c + 1) begin
        t_src(2'd2, r[1:0], c[3:0]);
        t_cmd(4'h9, 4'h0);                    // RDM from DUT2
      end
    end
    // Bank isolation: DUT1 keeps its data while DUT2 is addressed
    t_dcl(3'b000);
    t_src(2'd1, 2'd0, 4'h3);
    t_cmd(4'h9, 4'h0);                        // DUT1 cell (0,3) intact

    $display("=== TB intel_4002: status characters, both banks ===");
    for (r = 0; r < 4; r = r + 1) begin
      t_src(2'd1, r[1:0], 4'h0);
      for (c = 0; c < 4; c = c + 1) begin
        t_cmd({2'b01, c[1:0]}, 4'h5 + c[3:0] + {2'b00, r[1:0]});  // WR0-WR3
      end
      for (c = 0; c < 4; c = c + 1) begin
        t_cmd({2'b11, c[1:0]}, 4'h0);                    // RD0-RD3
      end
    end
    t_dcl(3'b100);
    for (r = 0; r < 4; r = r + 1) begin
      t_src(2'd2, r[1:0], 4'h0);
      for (c = 0; c < 4; c = c + 1) begin
        t_cmd({2'b01, c[1:0]}, ~({2'b00, c[1:0]} + {2'b00, r[1:0]}));
      end
      for (c = 0; c < 4; c = c + 1) begin
        t_cmd({2'b11, c[1:0]}, 4'h0);
      end
    end

    $display("=== TB intel_4002: ADM / SBM data supply ===");
    t_dcl(3'b000);
    t_src(2'd1, 2'd1, 4'h7);
    t_cmd(4'h0, 4'hc);              // WRM 0xC into (reg1,char7)
    t_cmd(4'hb, 4'h0);              // ADM: memory nibble 0xC must be driven
    t_cmd(4'h8, 4'h0);              // SBM: memory nibble 0xC must be driven
    t_cmd(4'h9, 4'h0);              // RDM: memory unchanged by ADM/SBM
    // CPU-side bookkeeping (chip only supplies the nibble): SBM of 0xC
    // from 0 with no borrow in: 0 + ~0xC + ~0 = 4, borrow out (CY=0)
    acc5 = 5'h0 + 5'h0c;
    tcy  = acc5[4];
    acc5 = 5'h0 + {1'b0, ~4'hc} + {4'b0000, ~tcy};
    chk (acc5[3:0] == 4'h4, 110);   // TB-side CPU arithmetic sanity only

    $display("=== TB intel_4002: WMP output ports ===");
    t_src(2'd1, 2'd2, 4'h0);
    t_cmd(4'h1, 4'h5);              // WMP 5 -> DUT1 port
    t_cmd(4'h1, 4'ha);              // WMP overwrite -> 0xA
    t_cmd(4'h1, 4'h0);              // WMP clear -> 0
    t_dcl(3'b100);
    t_src(2'd2, 2'd3, 4'hf);
    t_cmd(4'h1, 4'h3);              // WMP 3 -> DUT2 port, DUT1 port holds 0
    t_settle();
    chk (io1 === gm_port[0], 120);
    chk (io2 === gm_port[1], 121);

    $display("=== TB intel_4002: chip select / deselect ===");
    t_dcl(3'b000);
    // chips 0, 2, 3 on bank 0: nobody but DUT1 (chip 1) may respond
    t_src(2'd0, 2'd1, 4'h2);
    t_cmd(4'h9, 4'h0);              // expect undriven bus
    t_src(2'd2, 2'd1, 4'h2);
    t_cmd(4'h9, 4'h0);
    t_src(2'd3, 2'd1, 4'h2);
    t_cmd(4'h9, 4'h0);
    t_src(2'd1, 2'd1, 4'h2);
    t_cmd(4'h9, 4'h0);              // driven: value from DUT1 (reg1,char2)
    // bank 3: only DUT2 (chip 2) responds
    t_dcl(3'b100);
    t_src(2'd1, 2'd0, 4'h1);
    t_cmd(4'h9, 4'h0);              // chip 1 not on bank 3 -> undriven
    t_src(2'd2, 2'd0, 4'h1);
    t_cmd(4'h9, 4'h0);              // driven from DUT2
    t_src(2'd0, 2'd0, 4'h1);
    t_cmd(4'h0, 4'hf);              // WRM to chip 0 -> nobody stores it
    t_src(2'd2, 2'd0, 4'h1);
    t_cmd(4'h9, 4'h0);              // DUT2 cell (0,1) must be unchanged

    $display("=== TB intel_4002: wrong bank line ===");
    t_dcl(3'b001);                  // bank 1: no chip wired
    t_src(2'd1, 2'd0, 4'h0);
    t_cmd(4'h9, 4'h0);              // undriven
    t_dcl(3'b010);                  // bank 2: no chip wired
    t_cmd(4'h9, 4'h0);              // undriven (stale address, line low)
    t_dcl(3'b000);

    $display("=== TB intel_4002: ROM-side opcodes are ignored ===");
    t_src(2'd1, 2'd1, 4'h4);
    t_cmd(4'h2, 4'hf);              // WRR: no 4002 state change
    t_cmd(4'h3, 4'hf);              // WPM: no 4002 state change
    t_cmd(4'ha, 4'h0);              // RDR: no 4002 drive
    t_cmd(4'h9, 4'h0);              // RDM returns the untouched value

    $display("=== TB intel_4002: reset mid-operation ===");
    t_src(2'd1, 2'd0, 4'h0);
    t_cmd(4'h0, 4'h7);              // WRM 7
    t_cmd(4'h1, 4'h9);              // WMP 9 on DUT1 port
    t_reset();
    chk (io1 === 4'h0, 130);
    chk (io2 === 4'h0, 131);
    t_src(2'd1, 2'd0, 4'h0);
    t_cmd(4'h9, 4'h0);              // memory cleared -> drive 0
    t_cmd(4'h1, 4'h6);              // port writable again after reset
    t_settle();
    chk (io1 === 4'h6, 132);

    $display("=== TB intel_4002: randomized phase (fixed seed) ===");
    for (i = 0; i < 400; i = i + 1) begin
      lfsr = lfsr_next();
      rops  = lfsr[2:0];
      rchip = lfsr[4:3];
      rreg  = lfsr[6:5];
      rchar = lfsr[10:7];
      lfsr  = lfsr_next();
      rops_opa = lfsr[3:0];
      rdata    = lfsr[14:11];
      if (rops == 3'd0) begin
        lfsr = lfsr_next();
        t_dcl(lfsr[2:0]);
      end else if (rops == 3'd1) begin
        t_src(rchip, rreg, rchar);
      end else begin
        t_cmd(rops_opa, rdata);
      end
    end

    $display("=== TB intel_4002: done ===");
    if (n_fails == 0) begin
      $display("TEST PASSED: %0d checks, %0d cycles", n_checks, n_cycles);
    end else begin
      $display("TEST FAILED: %0d checks, %0d failures, %0d cycles",
               n_checks, n_fails, n_cycles);
    end
    $finish;
  end

endmodule
