// Self-checking testbench for the IBM System/360 M2 core.
//
// Tests:
//   1. the M1 directed program: every M1 instruction, an exact retirement
//      address trace, and the final architectural state;
//   2. operation exception (code 1): an unassigned opcode must store the
//      program old PSW at 0x28 with the updated instruction address and take
//      the program new PSW from 0x68;
//   3. SET PROGRAM MASK: condition code and program mask from a register;
//   4. SET SYSTEM MASK in supervisor state;
//   5. LOAD PSW: full PSW replacement, condition code and problem state;
//   6. privileged operation (code 2): SET SYSTEM MASK in problem state;
//   7. fixed-point overflow (code 8) with program-mask bit 36 set, checking the
//      completed instruction's old PSW (condition code 3, updated address);
//   8. specification exception (code 6) for an unaligned LOAD PSW;
//   9. directed arithmetic-unit, address-generation and decode checks.
//
// Expected values are derived from A22-6821-7 (Principles of Operation) and
// from the program listings, not from the RTL: see
// report/2026-11-08-m2-status-switching.md.
`timescale 1ns/1ps

module tb_ibm_s360_cpu;

  `include "ibm_s360_defs.svh"

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic ext_timer_req = 1'b0;
  logic        key_we = 1'b0;
  logic [5:0]  key_block = 6'd0;
  logic [3:0]  key_data = 4'd0;
  logic        key_fetch_protect = 1'b0;
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Storage model: 32 KiB, 32-bit words, big-endian bytes.
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
  logic [15:0]  int_code_dbg;
  logic         int_taken;
  logic         in_wait_state;
  logic         retire;
  logic [23:0]  retire_ia;
  logic [3:0]   retire_len;
  logic [511:0] gpr_dbg;

  ibm_s360_cpu #(.RESET_IA(24'h00_0100)) dut (
      .clk             (clk),
      .rst_n           (rst_n),
      .ext_timer_req   (ext_timer_req),
      .key_we          (key_we),
      .key_block       (key_block),
      .key_data        (key_data),
      .key_fetch_protect(key_fetch_protect),
      .mem_addr        (mem_addr),
      .mem_we          (mem_we),
      .mem_wdata       (mem_wdata),
      .mem_wbe         (mem_wbe),
      .mem_rdata       (mem_rdata),
      .psw             (psw),
      .ovf_pending     (ovf_pending),
      .int_code_dbg    (int_code_dbg),
      .int_taken       (int_taken),
      .in_wait_state   (in_wait_state),
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
  int  int_count = 0;
  logic [15:0] last_int_code = 16'd0;
  logic        int_taken_d = 1'b0;

  always @(posedge clk) begin
    int_taken_d <= int_taken;
    if (rst_n && int_taken) begin
      int_count <= int_count + 1;
    end
    if (rst_n && retire && trace_enable && trace_verbose) begin
      $display("RET %06h len=%0d", retire_ia, retire_len);
    end
    if (int_taken_d) begin
      last_int_code <= int_code_dbg;
      if (trace_verbose) begin
        $display("INT taken: code=%0d old_psw=%08h %08h", int_code_dbg,
                 mem[13'h0028 >> 2], mem[13'h002C >> 2]);
      end
    end
  end

  // M1 trace checking is enabled only for test 1.
  int  trace_idx = 0;
  bit  trace_enable = 1'b0;
  bit  trace_verbose = 1'b0;
  bit  trace_done = 1'b0;
  localparam int N_EXPECTED = 22;
  logic [23:0] expected_ia [0:N_EXPECTED-1];

  initial begin
    expected_ia = '{
        24'h00_0100, 24'h00_0104, 24'h00_0108, 24'h00_010C, 24'h00_0110,
        24'h00_0114, 24'h00_0118, 24'h00_0128, 24'h00_012C, 24'h00_0130,
        24'h00_0132, 24'h00_013A, 24'h00_013E, 24'h00_0142, 24'h00_0146,
        24'h00_014A, 24'h00_014E, 24'h00_0152, 24'h00_0154, 24'h00_0158,
        24'h00_015A, 24'h00_015E
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
        $display("FAIL trace[%0d]: retired ia=%06h outside the self-loop",
                 trace_idx, retire_ia);
        errors++;
      end else if (trace_idx >= N_EXPECTED + 2) begin
        trace_done <= 1'b1;
      end
      trace_idx <= trace_idx + 1;
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

  task automatic check_word(input logic [23:0] a, input logic [31:0] exp,
                            input string what);
    checks++;
    if (mem[a[14:2]] !== exp) begin
      $display("FAIL: storage[%06h] = %08h, expected %08h (%0s)",
               a, mem[a[14:2]], exp, what);
      errors++;
    end
  endtask

  function automatic logic [4:0] byte_lsb(input logic [1:0] off);
    byte_lsb = (5'd3 - {3'b000, off}) << 3;
  endfunction

  task automatic poke_byte(input logic [23:0] a, input logic [7:0] d);
    mem[a[14:2]][byte_lsb(a[1:0]) +: 8] = d;
  endtask

  task automatic poke_word(input logic [23:0] a, input logic [31:0] d);
    mem[a[14:2]] = d;
  endtask

  task automatic poke_dw(input logic [23:0] a, input logic [63:0] d);
    poke_word(a, d[63:32]);
    poke_word(a + 24'd4, d[31:0]);
  endtask

  function automatic logic [3:0] hex_nibble(input byte c);
    logic [7:0] v;
    if ((c >= "0") && (c <= "9")) begin
      v = c - 8'h30;
    end else if ((c >= "A") && (c <= "F")) begin
      v = c - 8'h41 + 8'h0A;
    end else if ((c >= "a") && (c <= "f")) begin
      v = c - 8'h61 + 8'h0A;
    end else begin
      v = 8'h00;
    end
    hex_nibble = v[3:0];
  endfunction

  // Write a hex byte string at base (two characters per byte, big-endian order).
  task automatic poke_hex(input logic [23:0] base, input string s);
    int n;
    n = s.len() / 2;
    for (int i = 0; i < n; i++) begin
      logic [3:0] hi, lo;
      hi = hex_nibble(s.getc(2*i));
      lo = hex_nibble(s.getc(2*i + 1));
      poke_byte(base + i[23:0], {hi, lo});
    end
  endtask

  task automatic clear_mem();
    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'd0;
    end
  endtask

  task automatic start_reset();
    rst_n = 1'b0;
    trace_enable = 1'b0;
    clear_mem();
    int_count = 0;
    last_int_code = 16'd0;
    repeat (2) @(posedge clk);
  endtask

  task automatic set_key(input int blk, input logic [3:0] key, input bit fetch_protect);
    key_we          = 1'b1;
    key_block       = blk[5:0];
    key_data        = key;
    key_fetch_protect = fetch_protect;
    @(posedge clk);
    #1;
    key_we = 1'b0;
  endtask

  task automatic run_cycles(input int n);
    // Hold reset for three clocks so the sequencer and PSW start from their
    // reset values before the program runs.
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;
    repeat (n) @(posedge clk);
    #1;
  endtask

  // A handler that sets R15 to its own address and loops there.
  task automatic poke_handler(input logic [23:0] base);
    logic [23:0] loop_addr;
    loop_addr = base + 24'd4;
    poke_hex(base, "41F0");
    poke_byte(base + 24'd2, loop_addr[15:8]);
    poke_byte(base + 24'd3, loop_addr[7:0]);
    poke_byte(base + 24'd4, 8'h07);   // BCR 15,15
    poke_byte(base + 24'd5, 8'hFF);
  endtask

  // ---------------------------------------------------------------------------
  // Directed ALU / address checks (same set as M1)
  // ---------------------------------------------------------------------------
  s360_alu_op_e alu_op_t;
  logic [31:0]  alu_a_t, alu_b_t, alu_y_t;
  logic [1:0]   alu_cc_t;
  logic         alu_ovf_t;

  ibm_s360_alu u_alu_t (
      .op (alu_op_t), .a (alu_a_t), .b (alu_b_t),
      .y (alu_y_t), .cc (alu_cc_t), .ovf (alu_ovf_t)
  );

  task automatic t_alu(input s360_alu_op_e op, input logic [31:0] a,
                       input logic [31:0] b, input logic [31:0] ey,
                       input logic [1:0] ecc, input bit eovf,
                       input string what);
    alu_op_t = op; alu_a_t = a; alu_b_t = b;
    #1;
    checks++;
    if ((alu_y_t !== ey) || (alu_cc_t !== ecc) || (alu_ovf_t !== eovf)) begin
      $display("FAIL alu %0s: y=%08h cc=%0d ovf=%0b, expected y=%08h cc=%0d ovf=%0b",
               what, alu_y_t, alu_cc_t, alu_ovf_t, ey, ecc, eovf);
      errors++;
    end
  endtask

  logic [3:0]  a_b_field, a_x_field;
  logic [31:0] a_b_val, a_x_val;
  logic [11:0] a_disp;
  logic [23:0] a_addr;

  ibm_s360_addr u_addr_t (
      .b_field(a_b_field), .x_field(a_x_field),
      .b_val(a_b_val), .x_val(a_x_val), .disp(a_disp), .addr(a_addr)
  );

  task automatic t_addr(input logic [3:0] bf, input logic [3:0] xf,
                        input logic [31:0] bv, input logic [31:0] xv,
                        input logic [11:0] d, input logic [23:0] ea,
                        input string what);
    a_b_field = bf; a_x_field = xf; a_b_val = bv; a_x_val = xv; a_disp = d;
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
  initial begin
    rst_n = 1'b0;
    trace_verbose = $test$plusargs("trace");
    clear_mem();


    // =========================================================================
    // Test 1: M1 directed program.
    // =========================================================================
    poke_hex(24'h00_0100,
      "4110020041200204583010005A3020005030100859301008");
    poke_hex(24'h00_0118, "4780012841500EAD41500BAD41600ABC");
    poke_hex(24'h00_0128, "9240100C9540100C12334720013A");
    poke_hex(24'h00_0136, "41500BAD543020005630200057302000");
    poke_hex(24'h00_0146, "50301010584010145A4010181B44");
    poke_hex(24'h00_0154, "55301000186341F0015E07FF");
    poke_word(24'h00_0200, 32'd7);
    poke_word(24'h00_0204, 32'd5);
    poke_word(24'h00_0214, 32'h7FFF_FFFF);
    poke_word(24'h00_0218, 32'd1);

    trace_enable = 1'b1;
    trace_idx = 0;
    run_cycles(300);

    checks++;
    if (!trace_done) begin
      $display("FAIL: program did not reach the self-loop");
      errors++;
    end
    check(ovf_pending, "overflow flag not set by the directed program");
    check(psw[23:0] === 24'h00_015E, "program is not in its self-loop");
    check(psw[29:28] === 2'd1, "final condition code is not 1");
    check(psw[31:30] === 2'd1, "ILC of the final BRANCH ON CONDITION is not 1");
    check_gpr(1, 32'h0000_0200);
    check_gpr(2, 32'h0000_0204);
    check_gpr(3, 32'h0000_0000);
    check_gpr(4, 32'h0000_0000);
    check_gpr(5, 32'h0000_0000);
    check_gpr(6, 32'h0000_0000);
    check_gpr(15, 32'h0000_015E);
    check_word(24'h00_0208, 32'd12, "ST result");
    check_word(24'h00_020C, 32'h4000_0000, "MVI byte");
    check_word(24'h00_0210, 32'd0, "X result");

    // =========================================================================
    // Test 2: operation exception (code 1).
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);  // new PSW -> 0x300
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "0000");                  // unassigned opcode
    run_cycles(80);

    check(int_count == 1, "operation exception was not taken exactly once");
    check(last_int_code == 16'd1, "operation exception code is not 1");
    check_word(24'h00_0028, 32'h0000_0001, "old PSW word 0 (code 1)");
    check_word(24'h00_002C, 32'h4000_0102, "old PSW word 1 (ILC 1, IA 0x102)");
    check_gpr(15, 32'h0000_0304);
    check(psw[23:0] === 24'h00_0304, "handler is not in its self-loop");

    // =========================================================================
    // Test 3: SET PROGRAM MASK (0x04) -- CC and program mask from register 2.
    // =========================================================================
    start_reset();
    poke_hex(24'h00_0100, "41200010042041F0010A07FF");
    run_cycles(40);

    check(int_count == 0, "SPM caused an unexpected interruption");
    check(psw[29:28] === 2'd0, "SPM did not set CC 0");
    check(psw[27:24] === 4'h1, "SPM did not set program mask bit 36");
    check(psw[23:0] === 24'h00_010A, "SPM program is not in its self-loop");

    // =========================================================================
    // Test 4: SET SYSTEM MASK (0x80) in supervisor state.
    // =========================================================================
    start_reset();
    poke_hex(24'h00_0100, "924004008000040041F0010C07FF");
    run_cycles(40);

    check(int_count == 0, "SSM caused an unexpected interruption");
    check(psw[63:56] === 8'h40, "SSM did not set system mask 0x40");
    check(psw[23:0] === 24'h00_010C, "SSM program is not in its self-loop");

    // =========================================================================
    // Test 5: LOAD PSW (0x82) -- full replacement, CC 2, program mask 0xF,
    // system mask 0x80, instruction address 0x120.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0070, 64'h8000_0000_AF00_0120);
    poke_hex(24'h00_0100, "82000070");
    poke_hex(24'h00_0120, "4140000741F0012807FF");
    run_cycles(60);

    check(int_count == 0, "LPSW caused an unexpected interruption");
    check(psw[63:56] === 8'h80, "LPSW did not load the system mask");
    check(psw[29:28] === 2'd2, "LPSW did not load CC 2");
    check(psw[27:24] === 4'hF, "LPSW did not load the program mask");
    check(psw[23:0] === 24'h00_0128, "LPSW did not transfer control to 0x120");
    check_gpr(4, 32'd7);

    // =========================================================================
    // Test 6: privileged operation (code 2) -- SSM in problem state.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_dw(24'h00_0070, 64'h0001_0000_0000_0108);  // problem state, IA 0x108
    poke_hex(24'h00_0100, "82000070");              // LPSW (supervisor)
    poke_hex(24'h00_0108, "80000400");              // SSM in problem state
    run_cycles(80);

    check(int_count == 1, "privileged-operation check did not fire once");
    check(last_int_code == 16'd2, "privileged-operation code is not 2");
    check_word(24'h00_0028, 32'h0001_0002, "old PSW keeps the problem state bit and code 2");
    check_word(24'h00_002C, 32'h8000_010C, "old PSW: ILC 2, IA 0x10C");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 7: fixed-point overflow (code 8) with program-mask bit 36 set.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_word(24'h00_0200, 32'h7FFF_FFFF);
    poke_word(24'h00_0204, 32'd1);
    poke_hex(24'h00_0100, "412000100420584002005A400204");
    run_cycles(90);

    check(int_count == 1, "overflow interruption did not fire once");
    check(last_int_code == 16'd8, "overflow interruption code is not 8");
    check_word(24'h00_0028, 32'h0000_0008, "overflow old PSW word 0 (code 8)");
    check_word(24'h00_002C, 32'hB100_010E,
               "overflow old PSW: ILC 2, CC 3, program mask 1, IA 0x10E");
    check_gpr(4, 32'h8000_0000);
    check(ovf_pending, "overflow flag not set");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 8: specification exception (code 6) -- unaligned LOAD PSW.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "82000072");
    run_cycles(60);

    check(int_count == 1, "specification exception did not fire once");
    check(last_int_code == 16'd6, "specification code is not 6");
    check_word(24'h00_002C, 32'h8000_0104, "old PSW: ILC 2, IA 0x104");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 9: halfword group -- LH, AH, STH, CH, MH.
    // =========================================================================
    start_reset();
    poke_word(24'h00_0200, 32'hFFFF_0002);  // halfword 0x200 = -1, 0x202 = 2
    poke_word(24'h00_0204, 32'h0000_0003);  // halfword 0x206 = 3
    poke_word(24'h00_0208, 32'hFFFE_0000);  // halfword 0x208 = -2
    poke_hex(24'h00_0100,
      "481002004A1002024010020449100206412000074C20020841F0011C07FF");
    run_cycles(80);

    check(int_count == 0, "halfword group caused an unexpected interruption");
    check_gpr(1, 32'h0000_0001);              // -1 + 2
    check_gpr(2, 32'hFFFF_FFF2);              // 7 * -2
    check_word(24'h00_0204, 32'h0001_0003, "STH wrote the high halfword");
    check(psw[29:28] === 2'd1, "CH did not set CC 1");

    // =========================================================================
    // Test 10: multiply and divide -- MR with a negative product, DR.
    // =========================================================================
    start_reset();
    poke_word(24'h00_0200, 32'hFFFF_FFF9);  // -7
    poke_hex(24'h00_0100,
      "41400006583002001C245020021050300214416000004170002A4180002A1D68506002185070021C41F0012C07FF");
    run_cycles(120);

    check(int_count == 0, "multiply/divide caused an unexpected interruption");
    check_gpr(2, 32'hFFFF_FFFF);              // high half of 6 * -7
    check_gpr(3, 32'hFFFF_FFD6);              // low half
    check_word(24'h00_0210, 32'hFFFF_FFFF, "MR high half stored");
    check_word(24'h00_0214, 32'hFFFF_FFD6, "MR low half stored");
    check_gpr(4, 32'h0000_0006);              // multiplier
    check_gpr(6, 32'h0000_0000);              // remainder (even register)
    check_gpr(7, 32'h0000_0001);              // quotient (odd register)
    check_word(24'h00_0218, 32'h0000_0000, "DR remainder stored");
    check_word(24'h00_021C, 32'h0000_0001, "DR quotient stored");

    // =========================================================================
    // Test 11: fixed-point divide exception (code 9), dividend unchanged.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "41400001416000011D46");
    run_cycles(80);

    check(int_count == 1, "divide exception did not fire once");
    check(last_int_code == 16'd9, "divide exception code is not 9");
    check_gpr(4, 32'h0000_0001);              // dividend high unchanged
    check_gpr(5, 32'h0000_0000);              // dividend low unchanged
    check_word(24'h00_002C, 32'h4000_010A, "divide old PSW: ILC 1, IA 0x10A");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 12: shifts -- SLA, SRA and an SLA overflow.
    // =========================================================================
    start_reset();
    poke_hex(24'h00_0100,
      "412000058B2000018A200001413000048B30001F41F0011807FF");
    run_cycles(80);

    check(int_count == 0, "shifts caused an unexpected interruption");
    check_gpr(2, 32'h0000_0005);              // 5 << 1 >> 1
    check_gpr(3, 32'h0000_0000);              // sign fixed, field shifted out
    check(psw[29:28] === 2'd3, "SLA overflow was not reported as CC 3");
    check(ovf_pending, "shift overflow did not set the overflow flag");

    // =========================================================================
    // Test 13: supervisor call -- code in old PSW bits 24-31, PSWs at 0x20/0x60.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0060, 64'h0000_0000_0000_0300);  // supervisor new PSW
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "0A2A");                   // SVC 42
    run_cycles(80);

    check(int_count == 1, "supervisor call did not fire once");
    check(last_int_code == 16'h002A, "supervisor-call code is not 42");
    check_word(24'h00_0020, 32'h0000_002A, "supervisor old PSW bits 24-31");
    check_word(24'h00_0024, 32'h4000_0102, "supervisor old PSW ILC/IA");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 14: specification exceptions -- odd halfword address and odd pair.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "48100201");              // LH 1,0x201 (odd)
    run_cycles(60);

    check(int_count == 1, "odd halfword address did not raise a specification");
    check(last_int_code == 16'd6, "odd halfword code is not 6");
    check_word(24'h00_002C, 32'h8000_0104, "odd halfword old PSW: ILC 2, IA 0x104");

    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "1C31");                  // MR 3,1 with odd R1
    run_cycles(60);

    check(int_count == 1, "odd pair register did not raise a specification");
    check(last_int_code == 16'd6, "odd pair register code is not 6");
    check_word(24'h00_002C, 32'h4000_0102, "odd pair old PSW: ILC 1, IA 0x102");

    // =========================================================================
    // Test 15: character and SS-format group -- MVC, XC, NC, OC, MVN, MVZ,
    // CLC, IC, STC, TM.
    // =========================================================================
    start_reset();
    poke_word(24'h00_0200, 32'hC1C2_C3C4);  // EBCDIC "ABCD"
    poke_word(24'h00_0204, 32'h4B4C_4D4E);  // EBCDIC ".<(>+"
    poke_hex(24'h00_0100,
      "D20302080200D70302080204D40302080200D60002080200D10002080204D30002080205D50002080205431002084210020C91800208910F02049140020841F0014207FF");
    run_cycles(400);

    check(int_count == 0, "character group caused an unexpected interruption");
    check_word(24'h00_0208, 32'h4B82_8280, "MVC/XC/NC/OC/MVN/MVZ result");
    check_word(24'h00_020C, 32'h4B00_0000, "STC stored the inserted character");
    check_gpr(1, 32'h0000_004B);
    check(psw[29:28] === 2'd3, "TM all-ones did not set CC 3");

    // =========================================================================
    // Test 16: TR -- translate a four-byte field through a 256-byte table.
    // =========================================================================
    start_reset();
    for (int i = 0; i < 256; i++) begin
      poke_byte(24'h00_0300 + i[23:0], i[7:0] + 8'd1);
    end
    poke_hex(24'h00_0200, "10203040");
    poke_hex(24'h00_0100, "DC030200030041F0010A07FF");
    run_cycles(300);

    check(int_count == 0, "TR caused an unexpected interruption");
    check_word(24'h00_0200, 32'h1121_3141, "TR translated each byte");

    // =========================================================================
    // Test 17: TRT -- a match before the end gives CC 1, an all-zero table CC 0.
    // =========================================================================
    start_reset();
    for (int i = 0; i < 256; i++) begin
      poke_byte(24'h00_0300 + i[23:0], 8'h00);
    end
    poke_byte(24'h00_0320, 8'h0F);          // function byte for argument 0x20
    poke_hex(24'h00_0200, "10203040");
    poke_hex(24'h00_0100, "DD030200030041F0010A07FF");
    run_cycles(300);

    check(int_count == 0, "TRT caused an unexpected interruption");
    check_gpr(1, 32'h0000_0201);            // argument address of the match
    check_gpr(2, 32'h0000_000F);            // function byte
    check(psw[29:28] === 2'd1, "TRT match before the end did not give CC 1");

    start_reset();
    for (int i = 0; i < 256; i++) begin
      poke_byte(24'h00_0300 + i[23:0], 8'h00);
    end
    poke_hex(24'h00_0200, "10203040");
    poke_hex(24'h00_0100, "DD030200030041F0010A07FF");
    run_cycles(300);

    check_gpr(1, 32'h0000_0000);            // untouched
    check_gpr(2, 32'h0000_0000);
    check(psw[29:28] === 2'd0, "TRT with all-zero table did not give CC 0");

    // =========================================================================
    // Test 18: EX -- the I1 byte is ORed into the subject instruction and the
    // PSW advances past EXECUTE; EXECUTE of EXECUTE raises code 3.
    // =========================================================================
    start_reset();
    poke_hex(24'h00_0210, "92001000");      // MVI 0(1),0x00
    poke_hex(24'h00_0100, "4120004041100220442002104130005541F0011407FF");
    run_cycles(120);

    check(int_count == 0, "EX caused an unexpected interruption");
    check_word(24'h00_0220, 32'h4000_0000, "EX did not OR the R1 mask into MVI");
    check_gpr(1, 32'h0000_0220);
    check_gpr(3, 32'h0000_0055);            // instruction after EX ran
    check(psw[23:0] === 24'h00_0114, "EX did not advance the PSW past itself");

    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0210, "44000000");      // subject is another EXECUTE
    poke_hex(24'h00_0100, "44200210");
    run_cycles(80);

    check(int_count == 1, "EXECUTE of EXECUTE did not raise an interruption");
    check(last_int_code == 16'd3, "execute exception code is not 3");
    check_word(24'h00_002C, 32'h8000_0104, "execute old PSW: ILC 2, IA 0x104");

    // =========================================================================
    // Test 19: addressing exception (code 5) -- an operand outside the
    // installed 64 KiB of storage.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_word(24'h00_0200, 32'h0001_0000);
    poke_hex(24'h00_0100, "5810020058201010");   // L 1,0x200; L 2,0x10(1)
    run_cycles(80);

    check(int_count == 1, "addressing exception did not fire once");
    check(last_int_code == 16'd5, "addressing exception code is not 5");
    check_word(24'h00_0028, 32'h0000_0005, "addressing old PSW code");
    check_word(24'h00_002C, 32'h8000_0108, "addressing old PSW: ILC 2, IA 0x108");
    check_gpr(2, 32'h0000_0000);            // operand not loaded
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 20: external (timer) interruption -- taken only when system-mask
    // bit 7 is set, old/new PSWs at 0x18/0x58, code 0x0080.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0058, 64'h0000_0000_0000_0300);  // external new PSW
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0200, "01000000");              // system mask byte
    poke_hex(24'h00_0100, "920102008000020041F0010C07FF");
    run_cycles(40);
    check(int_count == 0, "timer taken while masked off");

    ext_timer_req = 1'b1;
    @(posedge clk);
    #1 ext_timer_req = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    check(int_count == 1, "timer interruption did not fire once");
    check(last_int_code == 16'h0080, "timer interruption code is not 0x0080");
    check_word(24'h00_0018, 32'h0100_0080, "external old PSW word 0");
    check_word(24'h00_001C, 32'h4000_010C, "external old PSW word 1 (ILC 1, IA 0x10C)");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 21: specification exception for an odd instruction address -- the
    // PSW is loaded with IA 0x105, so no instruction can be fetched.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_dw(24'h00_0070, 64'h0000_0000_0000_0105);
    poke_hex(24'h00_0100, "82000070");
    run_cycles(80);

    check(int_count == 1, "odd instruction address did not raise an interruption");
    check(last_int_code == 16'd6, "odd instruction address code is not 6");
    check_word(24'h00_0028, 32'h0000_0006, "odd IA old PSW code");
    check_word(24'h00_002C, 32'h0000_0105, "odd IA old PSW: ILC 0, IA 0x105");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 22: addressing exception for an instruction address outside the
    // installed 64 KiB -- PSW IA 0x010000.
    // =========================================================================
    start_reset();
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_dw(24'h00_0070, 64'h0000_0000_0001_0000);
    poke_hex(24'h00_0100, "82000070");
    run_cycles(80);

    check(int_count == 1, "unfetchable instruction did not raise an interruption");
    check(last_int_code == 16'd5, "unfetchable instruction code is not 5");
    check_word(24'h00_0028, 32'h0000_0005, "unfetchable old PSW code");
    check_word(24'h00_002C, 32'h0001_0000, "unfetchable old PSW: ILC 0, IA 0x10000");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 23: protection exception on a store -- block 0 carries key 1, the
    // PSW key is 0, so MVI is suppressed (code 4).
    // =========================================================================
    start_reset();
    run_cycles(4);
    set_key(0, 4'd1, 1'b0);
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_hex(24'h00_0100, "4110020092551000");
    run_cycles(80);

    check(int_count == 1, "store protection did not fire once");
    check(last_int_code == 16'd4, "store protection code is not 4");
    check_word(24'h00_0028, 32'h0000_0004, "store protection old PSW code");
    check_word(24'h00_002C, 32'h8000_0108, "store protection old PSW: ILC 2, IA 0x108");
    check_word(24'h00_0200, 32'h0000_0000, "protected storage was written");
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 24: protection exception on an operand fetch -- block 0 has key 1
    // and fetch protection, the PSW key is 0.
    // =========================================================================
    start_reset();
    run_cycles(4);
    set_key(0, 4'd1, 1'b1);
    poke_dw(24'h00_0068, 64'h0000_0000_0000_0300);
    poke_handler(24'h00_0300);
    poke_word(24'h00_0200, 32'h1234_5678);
    poke_hex(24'h00_0100, "4110020058201000");
    run_cycles(80);

    check(int_count == 1, "fetch protection did not fire once");
    check(last_int_code == 16'd4, "fetch protection code is not 4");
    check_word(24'h00_002C, 32'h8000_0108, "fetch protection old PSW: ILC 2, IA 0x108");
    check_gpr(2, 32'h0000_0000);            // operand not loaded
    check_gpr(15, 32'h0000_0304);

    // =========================================================================
    // Test 25: a matching protection key permits the reference -- block 0 has
    // key 1 and fetch protection, and LPSW from block 1 installs PSW key 1.
    // =========================================================================
    start_reset();
    run_cycles(4);
    set_key(0, 4'd1, 1'b1);
    set_key(1, 4'd0, 1'b0);
    poke_word(24'h00_0200, 32'h1234_5678);
    poke_dw(24'h00_0800, 64'h0010_0000_0000_0110);   // key 1, IA 0x110
    poke_hex(24'h00_0100, "82000800");
    poke_hex(24'h00_0110, "411002005820100041F0011C07FF");
    run_cycles(120);

    check(int_count == 0, "matching key still raised an interruption");
    check_gpr(2, 32'h1234_5678);
    check(psw[55:52] === 4'h1, "PSW key was not loaded as 1");
    check(psw[23:0] === 24'h00_011C, "program is not in its self-loop");

    // =========================================================================
    // Test 26: directed arithmetic unit, address generation and decode checks.
    // =========================================================================
    t_alu(ALU_ADD, 32'd7, 32'd5, 32'd12, 2'd2, 1'b0, "add positive");
    t_alu(ALU_ADD, 32'h7FFF_FFFF, 32'd1, 32'h8000_0000, 2'd3, 1'b1, "add positive overflow");
    t_alu(ALU_ADD, 32'h8000_0000, 32'h8000_0000, 32'd0, 2'd3, 1'b1, "add negative overflow to zero");
    t_alu(ALU_ADD, 32'hFFFF_FFFF, 32'd1, 32'd0, 2'd0, 1'b0, "add with carry out");
    t_alu(ALU_SUB, 32'd5, 32'd7, 32'hFFFF_FFFE, 2'd1, 1'b0, "subtract negative result");
    t_alu(ALU_SUB, 32'h8000_0000, 32'd1, 32'h7FFF_FFFF, 2'd3, 1'b1, "subtract overflow");
    t_alu(ALU_CMP, 32'h8000_0000, 32'd1, 32'd0, 2'd1, 1'b0, "compare signed across overflow");
    t_alu(ALU_CMP, 32'd1, 32'h8000_0000, 32'd0, 2'd2, 1'b0, "compare signed high");
    t_alu(ALU_CLR, 32'hFFFF_FFFF, 32'd1, 32'd0, 2'd2, 1'b0, "compare logical high");
    t_alu(ALU_TEST, 32'h8000_0000, 32'd0, 32'h8000_0000, 2'd1, 1'b0, "load and test negative");

    t_addr(4'd0, 4'd0, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 12'h123, 24'h00_0123,
           "zero base and index ignore register contents");
    t_addr(4'd5, 4'd0, 32'hAB12_3456, 32'hFFFF_FFFF, 12'h000, 24'h12_3456,
           "high-order register bits ignored");

    begin
      s360_dec_t d;
      d = s360_decode(8'h82);
      check(d.valid && (d.op == OP_LPSW) && (d.fmt == FMT_RS_SI), "decode 0x82 as LPSW/SI");
      d = s360_decode(8'h80);
      check(d.valid && (d.op == OP_SSM) && (d.fmt == FMT_RS_SI), "decode 0x80 as SSM/SI");
      d = s360_decode(8'h04);
      check(d.valid && (d.op == OP_SPM) && (d.fmt == FMT_RR), "decode 0x04 as SPM/RR");
      d = s360_decode(8'h00);
      check(!d.valid && (d.fmt == FMT_RR), "decode 0x00 as an unassigned RR opcode");
      d = s360_decode(8'h1C);
      check(d.valid && (d.op == OP_MR) && (d.fmt == FMT_RR), "decode 0x1C as MR/RR");
      d = s360_decode(8'h5D);
      check(d.valid && (d.op == OP_D) && (d.fmt == FMT_RX), "decode 0x5D as D/RX");
      d = s360_decode(8'h8F);
      check(d.valid && (d.op == OP_SLDA) && (d.fmt == FMT_RS_SI), "decode 0x8F as SLDA/RS");
      d = s360_decode(8'h0A);
      check(d.valid && (d.op == OP_SVC) && (d.fmt == FMT_RR), "decode 0x0A as SVC/RR");
      d = s360_decode(8'h4C);
      check(d.valid && (d.op == OP_MH) && (d.fmt == FMT_RX), "decode 0x4C as MH/RX");
      d = s360_decode(8'hD2);
      check(d.valid && (d.op == OP_MVC) && (d.fmt == FMT_SS), "decode 0xD2 as MVC/SS");
      d = s360_decode(8'hD5);
      check(d.valid && (d.op == OP_CLC) && (d.fmt == FMT_SS), "decode 0xD5 as CLC/SS");
      d = s360_decode(8'h91);
      check(d.valid && (d.op == OP_TM) && (d.fmt == FMT_RS_SI), "decode 0x91 as TM/SI");
      d = s360_decode(8'h43);
      check(d.valid && (d.op == OP_IC) && (d.fmt == FMT_RX), "decode 0x43 as IC/RX");
      d = s360_decode(8'hDC);
      check(d.valid && (d.op == OP_TR) && (d.fmt == FMT_SS), "decode 0xDC as TR/SS");
      d = s360_decode(8'hDD);
      check(d.valid && (d.op == OP_TRT) && (d.fmt == FMT_SS), "decode 0xDD as TRT/SS");
      d = s360_decode(8'h44);
      check(d.valid && (d.op == OP_EX) && (d.fmt == FMT_RX), "decode 0x44 as EX/RX");
    end

    // =========================================================================
    // Report
    // =========================================================================
    if (errors == 0) begin
      $display("IBM S360 M8 CORE TESTS PASSED (%0d checks)", checks);
      $finish;
    end else begin
      $display("IBM S360 M8 CORE TESTS FAILED: %0d error(s) in %0d checks", errors, checks);
      $fatal(1, "testbench failures");
    end
  end

  initial begin
    #500_000;
    $display("FAIL: watchdog timeout");
    $fatal(1, "timeout");
  end

endmodule
