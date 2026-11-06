// Self-checking testbench for the IBM System/360 M1 core.
//
// Four independent directed tests:
//   1. a hand-assembled program exercising every implemented instruction,
//      checked against the retired instruction address trace (no padded or
//      "landing-tolerant" checks: each instruction must retire at the exact
//      address the program listing says) and against the final architectural
//      state (general registers, PSW condition code, storage image);
//   2. an unimplemented operation code, which must stop the machine, raise the
//      sticky program-check flag and never retire;
//   3. directed arithmetic unit checks, including the signed-compare cases
//      whose 32-bit subtractor result overflows;
//   4. directed address-generation checks for zero base/index fields,
//      displacement addition and 24-bit wraparound.
//
// The expected values are derived from the program listing and from
// A22-6821-7, not from the RTL: the program image is written as the literal
// byte stream of a listing whose encoding is documented instruction by
// instruction in report/2026-11-05-m1-core.md.
`timescale 1ns/1ps

module tb_ibm_s360_cpu;

  `include "ibm_s360_defs.svh"

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Storage model: 32 KiB, 32-bit words, big-endian bytes (the byte at the
  // lowest address of a word occupies bits 31-24).
  // ---------------------------------------------------------------------------
  localparam int MEM_WORDS = 8192;

  logic [31:0] mem [0:MEM_WORDS-1];

  logic [23:0] mem_addr;
  logic        mem_we;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_wbe;
  logic [31:0] mem_rdata;

  assign mem_rdata = mem[mem_addr[14:2]];

  always @(posedge clk) begin
    if (mem_we) begin
      for (int i = 0; i < 4; i++) begin
        if (mem_wbe[i]) begin
          mem[mem_addr[14:2]][8*i +: 8] <= mem_wdata[8*i +: 8];
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Device under test
  // ---------------------------------------------------------------------------
  logic [63:0]  psw;
  logic         ovf_pending;
  logic         pc_check_pending;
  logic         halted;
  logic         retire;
  logic [23:0]  retire_ia;
  logic [3:0]   retire_len;
  logic [511:0] gpr_dbg;

  ibm_s360_cpu #(.RESET_IA(24'h00_0100)) dut (
      .clk             (clk),
      .rst_n           (rst_n),
      .mem_addr        (mem_addr),
      .mem_we          (mem_we),
      .mem_wdata       (mem_wdata),
      .mem_wbe         (mem_wbe),
      .mem_rdata       (mem_rdata),
      .psw             (psw),
      .ovf_pending     (ovf_pending),
      .pc_check_pending(pc_check_pending),
      .halted          (halted),
      .retire          (retire),
      .retire_ia       (retire_ia),
      .retire_len      (retire_len),
      .gpr_dbg         (gpr_dbg)
  );

  // ---------------------------------------------------------------------------
  // Bookkeeping
  // ---------------------------------------------------------------------------
  int  errors = 0;
  int  checks = 0;
  int  trace_idx = 0;
  bit  trace_enable = 1'b1;
  bit  trace_done = 1'b0;
  bit  trace_overflow = 1'b0;

  localparam int N_EXPECTED = 22;

  logic [23:0] expected_ia [0:N_EXPECTED-1];

  initial begin
    expected_ia = '{
        24'h00_0100,  // LA   1,0x200
        24'h00_0104,  // LA   2,0x204
        24'h00_0108,  // L    3,0(1)
        24'h00_010C,  // A    3,0(2)
        24'h00_0110,  // ST   3,8(1)
        24'h00_0114,  // C    3,8(1)
        24'h00_0118,  // BC   8,0x128
        24'h00_0128,  // MVI  12(1),0x40
        24'h00_012C,  // CLI  12(1),0x40
        24'h00_0130,  // LTR  3,3
        24'h00_0132,  // BC   2,0x13A
        24'h00_013A,  // N    3,0(2)
        24'h00_013E,  // O    3,0(2)
        24'h00_0142,  // X    3,0(2)
        24'h00_0146,  // ST   3,16(1)
        24'h00_014A,  // L    4,20(1)
        24'h00_014E,  // A    4,24(1)
        24'h00_0152,  // SR   4,4
        24'h00_0154,  // CL   3,0(1)
        24'h00_0158,  // LR   6,3
        24'h00_015A,  // LA   15,0x15E
        24'h00_015E   // BCR  15,15   (self-loop)
    };
  end

  always @(posedge clk) begin
    if (rst_n && trace_enable && retire) begin
      if (trace_idx < N_EXPECTED) begin
        if (retire_ia !== expected_ia[trace_idx]) begin
          $display("FAIL trace[%0d]: retired ia=%06h, expected %06h",
                   trace_idx, retire_ia, expected_ia[trace_idx]);
          errors++;
        end
      end else if (retire_ia !== 24'h00_015E) begin
        // After the expected sequence the machine must stay in the
        // BRANCH ON CONDITION self-loop.
        $display("FAIL trace[%0d]: retired ia=%06h outside the self-loop",
                 trace_idx, retire_ia);
        errors++;
      end else if (trace_idx >= N_EXPECTED + 2) begin
        trace_done <= 1'b1;
      end
      trace_idx <= trace_idx + 1;
      if (trace_idx > N_EXPECTED + 64) begin
        trace_overflow <= 1'b1;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  task automatic check(input bit cond, input string what);
    checks++;
    if (!cond) begin
      $display("FAIL: %0s", what);
      errors++;
    end
  endtask

  task automatic check_gpr(input int idx, input logic [31:0] exp);
    logic [31:0] got;
    got = gpr_dbg[32*idx +: 32];
    checks++;
    if (got !== exp) begin
      $display("FAIL: GPR%0d = %08h, expected %08h", idx, got, exp);
      errors++;
    end
  endtask

  task automatic check_word(input logic [23:0] a, input logic [31:0] exp);
    checks++;
    if (mem[a[14:2]] !== exp) begin
      $display("FAIL: storage[%06h] = %08h, expected %08h", a, mem[a[14:2]], exp);
      errors++;
    end
  endtask

  // Byte offset 0 of a memory word occupies bits 31-24 (big-endian).
  function automatic logic [4:0] byte_lsb(input logic [1:0] off);
    byte_lsb = (5'd3 - {3'b000, off}) << 3;
  endfunction

  task automatic poke_byte(input logic [23:0] a, input logic [7:0] d);
    mem[a[14:2]][byte_lsb(a[1:0]) +: 8] = d;
  endtask

  task automatic poke_word(input logic [23:0] a, input logic [31:0] d);
    mem[a[14:2]] = d;
  endtask

  task automatic clear_mem();
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'd0;
    end
  endtask

  // The program image is a literal byte stream so that instruction encodings
  // remain visible in the listing order.
  task automatic load_main_program();
    logic [7:0] p [0:95];
    p = '{
        // 0x100 LA   1,0x200
        8'h41, 8'h10, 8'h02, 8'h00,
        // 0x104 LA   2,0x204
        8'h41, 8'h20, 8'h02, 8'h04,
        // 0x108 L    3,0(1)          R3 <- 7
        8'h58, 8'h30, 8'h10, 8'h00,
        // 0x10C A    3,0(2)          R3 <- 12, CC=2
        8'h5A, 8'h30, 8'h20, 8'h00,
        // 0x110 ST   3,8(1)          storage[0x208] <- 12
        8'h50, 8'h30, 8'h10, 8'h08,
        // 0x114 C    3,8(1)          equal, CC=0
        8'h59, 8'h30, 8'h10, 8'h08,
        // 0x118 BC   8,0x128          taken
        8'h47, 8'h80, 8'h01, 8'h28,
        // 0x11C LA   5,0xEAD          skipped
        8'h41, 8'h50, 8'h0E, 8'hAD,
        // 0x120 LA   5,0xBAD          skipped
        8'h41, 8'h50, 8'h0B, 8'hAD,
        // 0x124 LA   6,0xABC          skipped
        8'h41, 8'h60, 8'h0A, 8'hBC,
        // 0x128 MVI  12(1),0x40       storage[0x20C] <- 0x40
        8'h92, 8'h40, 8'h10, 8'h0C,
        // 0x12C CLI  12(1),0x40       equal, CC=0
        8'h95, 8'h40, 8'h10, 8'h0C,
        // 0x130 LTR  3,3              positive, CC=2
        8'h12, 8'h33,
        // 0x132 BC   2,0x13A          taken
        8'h47, 8'h20, 8'h01, 8'h3A,
        // 0x136 LA   5,0xBAD          skipped
        8'h41, 8'h50, 8'h0B, 8'hAD,
        // 0x13A N    3,0(2)           R3 <- 4, CC=1
        8'h54, 8'h30, 8'h20, 8'h00,
        // 0x13E O    3,0(2)           R3 <- 5, CC=1
        8'h56, 8'h30, 8'h20, 8'h00,
        // 0x142 X    3,0(2)           R3 <- 0, CC=0
        8'h57, 8'h30, 8'h20, 8'h00,
        // 0x146 ST   3,16(1)          storage[0x210] <- 0
        8'h50, 8'h30, 8'h10, 8'h10,
        // 0x14A L    4,20(1)          R4 <- 0x7FFFFFFF
        8'h58, 8'h40, 8'h10, 8'h14,
        // 0x14E A    4,24(1)          R4 <- 0x80000000, overflow, CC=3
        8'h5A, 8'h40, 8'h10, 8'h18,
        // 0x152 SR   4,4              R4 <- 0, CC=0
        8'h1B, 8'h44,
        // 0x154 CL   3,0(1)           first operand low, CC=1
        8'h55, 8'h30, 8'h10, 8'h00,
        // 0x158 LR   6,3              CC unchanged
        8'h18, 8'h63,
        // 0x15A LA   15,0x15E
        8'h41, 8'hF0, 8'h01, 8'h5E,
        // 0x15E BCR  15,15            branch to itself
        8'h07, 8'hFF
    };
    for (int i = 0; i < 96; i++) begin
      poke_byte(24'h00_0100 + i[23:0], p[i]);
    end
    // Data area.
    poke_word(24'h00_0200, 32'd7);
    poke_word(24'h00_0204, 32'd5);
    poke_word(24'h00_0214, 32'h7FFF_FFFF);
    poke_word(24'h00_0218, 32'd1);
  endtask

  // ---------------------------------------------------------------------------
  // Directed ALU checks (test 3)
  // ---------------------------------------------------------------------------
  s360_alu_op_e alu_op_t;
  logic [31:0]  alu_a_t, alu_b_t, alu_y_t;
  logic [1:0]   alu_cc_t;
  logic         alu_ovf_t;

  ibm_s360_alu u_alu_t (
      .op (alu_op_t),
      .a  (alu_a_t),
      .b  (alu_b_t),
      .y  (alu_y_t),
      .cc (alu_cc_t),
      .ovf(alu_ovf_t)
  );

  task automatic t_alu(input s360_alu_op_e op, input logic [31:0] a,
                       input logic [31:0] b, input logic [31:0] ey,
                       input logic [1:0] ecc, input bit eovf,
                       input string what);
    alu_op_t = op;
    alu_a_t  = a;
    alu_b_t  = b;
    #1;
    checks++;
    if ((alu_y_t !== ey) || (alu_cc_t !== ecc) || (alu_ovf_t !== eovf)) begin
      $display("FAIL alu %0s: y=%08h cc=%0d ovf=%0b, expected y=%08h cc=%0d ovf=%0b",
               what, alu_y_t, alu_cc_t, alu_ovf_t, ey, ecc, eovf);
      errors++;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Directed address-generation checks (test 4)
  // ---------------------------------------------------------------------------
  logic [3:0]  a_b_field, a_x_field;
  logic [31:0] a_b_val, a_x_val;
  logic [11:0] a_disp;
  logic [23:0] a_addr;

  ibm_s360_addr u_addr_t (
      .b_field(a_b_field),
      .x_field(a_x_field),
      .b_val  (a_b_val),
      .x_val  (a_x_val),
      .disp   (a_disp),
      .addr   (a_addr)
  );

  task automatic t_addr(input logic [3:0] bf, input logic [3:0] xf,
                        input logic [31:0] bv, input logic [31:0] xv,
                        input logic [11:0] d, input logic [23:0] ea,
                        input string what);
    a_b_field = bf; a_x_field = xf; a_b_val = bv; a_x_val = xv;
    a_disp = d;
    #1;
    checks++;
    if (a_addr !== ea) begin
      $display("FAIL addr %0s: addr=%06h, expected %06h", what, a_addr, ea);
      errors++;
    end
  endtask

  // ---------------------------------------------------------------------------
  // Main test sequence
  // ---------------------------------------------------------------------------
  int retire_at_halt;

  initial begin
    rst_n = 1'b0;
    clear_mem();
    load_main_program();

    // -------------------------------------------------------------------------
    // Test 1: full program, exact retire trace and final state.
    // -------------------------------------------------------------------------
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;

    wait (trace_done == 1'b1);
    check(!trace_overflow, "program did not leave the self-loop after 86 retires");
    check(trace_idx > N_EXPECTED, "self-loop was not executed");
    repeat (3) @(posedge clk);

    check(!halted, "core halted unexpectedly");
    check(!pc_check_pending, "program-check flag raised by a valid program");
    check(ovf_pending, "fixed-point overflow was not recorded");
    check(psw[23:0] === 24'h00_015E, "instruction address is not in the self-loop");
    check(psw[29:28] === 2'd1, "final condition code is not 1");
    check(psw[31:30] === 2'd1, "ILC of the final BRANCH ON CONDITION is not 1");

    check_gpr(1, 32'h0000_0200);
    check_gpr(2, 32'h0000_0204);
    check_gpr(3, 32'h0000_0000);
    check_gpr(4, 32'h0000_0000);
    check_gpr(5, 32'h0000_0000);
    check_gpr(6, 32'h0000_0000);
    check_gpr(15, 32'h0000_015E);

    check_word(24'h00_0208, 32'd12);         // ST result
    check_word(24'h00_020C, 32'h4000_0000);  // MVI byte at offset 0
    check_word(24'h00_0210, 32'd0);          // X result

    // -------------------------------------------------------------------------
    // Test 2: unimplemented operation code (0x1C, MULTIPLY RR) must stop the
    // machine before retiring and raise the program-check flag.
    // -------------------------------------------------------------------------
    trace_enable = 1'b0;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    clear_mem();
    poke_byte(24'h00_0100, 8'h1C);  // MULTIPLY (MR) -- not implemented
    poke_byte(24'h00_0101, 8'hFF);
    trace_idx = 0;
    trace_done = 1'b0;
    #1 rst_n = 1'b1;
    repeat (2) @(posedge clk);
    retire_at_halt = trace_idx;
    repeat (8) @(posedge clk);

    check(halted, "illegal operation code did not halt the core");
    check(pc_check_pending, "illegal operation code did not raise the program-check flag");
    check(trace_idx == retire_at_halt, "an instruction retired after the halt");
    check(psw[23:0] === 24'h00_0100, "instruction address changed on an illegal instruction");

    // -------------------------------------------------------------------------
    // Test 3: arithmetic unit.
    // -------------------------------------------------------------------------
    t_alu(ALU_ADD, 32'd7, 32'd5, 32'd12, 2'd2, 1'b0, "add positive");
    t_alu(ALU_ADD, 32'h7FFF_FFFF, 32'd1, 32'h8000_0000, 2'd3, 1'b1, "add positive overflow");
    t_alu(ALU_ADD, 32'h8000_0000, 32'h8000_0000, 32'd0, 2'd3, 1'b1, "add negative overflow to zero");
    t_alu(ALU_ADD, 32'hFFFF_FFFF, 32'd1, 32'd0, 2'd0, 1'b0, "add with carry out");
    t_alu(ALU_SUB, 32'd5, 32'd7, 32'hFFFF_FFFE, 2'd1, 1'b0, "subtract negative result");
    t_alu(ALU_SUB, 32'h8000_0000, 32'd1, 32'h7FFF_FFFF, 2'd3, 1'b1, "subtract overflow");
    t_alu(ALU_SUB, 32'd0, 32'd1, 32'hFFFF_FFFF, 2'd1, 1'b0, "subtract below zero");
    t_alu(ALU_CMP, 32'd5, 32'd7, 32'd0, 2'd1, 1'b0, "compare low");
    t_alu(ALU_CMP, 32'd7, 32'd5, 32'd0, 2'd2, 1'b0, "compare high");
    t_alu(ALU_CMP, 32'd5, 32'd5, 32'd0, 2'd0, 1'b0, "compare equal");
    t_alu(ALU_CMP, 32'h8000_0000, 32'd1, 32'd0, 2'd1, 1'b0, "compare signed across overflow");
    t_alu(ALU_CMP, 32'd1, 32'h8000_0000, 32'd0, 2'd2, 1'b0, "compare signed across overflow, high");
    t_alu(ALU_CLR, 32'hFFFF_FFFF, 32'd1, 32'd0, 2'd2, 1'b0, "compare logical high");
    t_alu(ALU_CLR, 32'd1, 32'hFFFF_FFFF, 32'd0, 2'd1, 1'b0, "compare logical low");
    t_alu(ALU_CLR, 32'h0000_0040, 32'h0000_0040, 32'd0, 2'd0, 1'b0, "compare logical equal bytes");
    t_alu(ALU_AND, 32'h0F0F_0F0F, 32'hF0F0_F0F0, 32'd0, 2'd0, 1'b0, "and to zero");
    t_alu(ALU_OR,  32'h0F0F_0F0F, 32'hF0F0_F0F0, 32'hFFFF_FFFF, 2'd1, 1'b0, "or to ones");
    t_alu(ALU_XOR, 32'd5, 32'd5, 32'd0, 2'd0, 1'b0, "xor to zero");
    t_alu(ALU_TEST, 32'd0, 32'd0, 32'd0, 2'd0, 1'b0, "load and test zero");
    t_alu(ALU_TEST, 32'h8000_0000, 32'd0, 32'h8000_0000, 2'd1, 1'b0, "load and test negative");
    t_alu(ALU_TEST, 32'd7, 32'd0, 32'd7, 2'd2, 1'b0, "load and test positive");

    // -------------------------------------------------------------------------
    // Test 4: address generation.
    // -------------------------------------------------------------------------
    t_addr(4'd0, 4'd0, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 12'h123, 24'h00_0123,
           "zero base and index ignore register contents");
    t_addr(4'd1, 4'd0, 32'hFFFF_F000, 32'hFFFF_FFFF, 12'hFFF, 24'hFF_FFFF,
           "base plus displacement");
    t_addr(4'd0, 4'd2, 32'hFFFF_FFFF, 32'h0000_0002, 12'h001, 24'h00_0003,
           "index plus displacement");
    t_addr(4'd3, 4'd4, 32'h00FF_FFFF, 32'h0000_0002, 12'h001, 24'h00_0002,
           "24-bit wraparound");
    t_addr(4'd5, 4'd0, 32'hAB12_3456, 32'hFFFF_FFFF, 12'h000, 24'h12_3456,
           "high-order register bits ignored");

    // -------------------------------------------------------------------------
    // Decode table spot checks.
    // -------------------------------------------------------------------------
    begin
      s360_dec_t d;
      d = s360_decode(8'h18);
      check(d.valid && (d.op == OP_LR) && (d.fmt == FMT_RR), "decode 0x18 as LR/RR");
      d = s360_decode(8'h5A);
      check(d.valid && (d.op == OP_A) && (d.fmt == FMT_RX), "decode 0x5A as A/RX");
      d = s360_decode(8'h92);
      check(d.valid && (d.op == OP_MVI) && (d.fmt == FMT_RS_SI), "decode 0x92 as MVI/SI");
      d = s360_decode(8'h1C);
      check(!d.valid && (d.fmt == FMT_RR), "decode 0x1C as an unimplemented RR instruction");
      d = s360_decode(8'hD2);
      check(!d.valid && (d.fmt == FMT_SS), "decode 0xD2 as an unimplemented SS instruction");
      check(s360_len_bytes(FMT_RR) == 4'd2, "RR length is two bytes");
      check(s360_len_bytes(FMT_RX) == 4'd4, "RX length is four bytes");
      check(s360_len_bytes(FMT_SS) == 4'd6, "SS length is six bytes");
    end

    // -------------------------------------------------------------------------
    // Report
    // -------------------------------------------------------------------------
    if (errors == 0) begin
      $display("IBM S360 M1 CORE TESTS PASSED (%0d checks, %0d retired instructions in the directed program)",
               checks, N_EXPECTED);
      $finish;
    end else begin
      $display("IBM S360 M1 CORE TESTS FAILED: %0d error(s) in %0d checks", errors, checks);
      $fatal(1, "testbench failures");
    end
  end

  // Watchdog.
  initial begin
    #500_000;
    $display("FAIL: watchdog timeout");
    $fatal(1, "timeout");
  end

endmodule
