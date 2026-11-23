// Oracle-mode testbench: run a program image for a fixed number of retired
// instructions and dump architectural state for comparison with an independent
// emulator (issue #383).
//
// Plusargs:
//   +prog=<file>    hex words, one per line, loaded at 0x100
//   +words=<n>      number of words in that file
//   +steps=<n>      retired instructions to run before dumping
//   +out=<file>     where to write the state dump
//
// The dump is line oriented so the same parser can read the independent
// emulator's output:
//   psw <16 hex digits>
//   gpr <index> <8 hex digits>     (16 lines)
//   mem <address> <8 hex digits>   (words 0x200..0x23F)
`timescale 1ns/1ps

module tb_oracle;

  `include "ibm_s360_defs.svh"

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  localparam int MEM_WORDS = 16384;   // 64 KiB

  logic [31:0] mem [0:MEM_WORDS-1];

  logic [23:0] mem_addr;
  logic        mem_we;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_wbe;
  logic [31:0] mem_rdata;

  assign mem_rdata = mem[mem_addr[15:2]];

  always @(posedge clk) begin
    if (mem_we) begin
      for (int i = 0; i < 4; i++) begin
        if (mem_wbe[i]) begin
          mem[mem_addr[15:2]][8*i +: 8] <= mem_wdata[8*i +: 8];
        end
      end
    end
  end

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
      .ext_timer_req   (1'b0),
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

  initial begin
    string prog_path;
    string out_path;
    int    words;
    int    steps;
    int    retired;
    int    fd;

    for (int i = 0; i < MEM_WORDS; i++) begin
      mem[i] = 32'd0;
    end

    if (!$value$plusargs("prog=%s", prog_path)) begin
      $display("FAIL: +prog=<file> is required");
      $fatal(1);
    end
    if (!$value$plusargs("out=%s", out_path)) begin
      $display("FAIL: +out=<file> is required");
      $fatal(1);
    end
    if (!$value$plusargs("words=%d", words)) words = 0;
    if (!$value$plusargs("steps=%d", steps)) steps = 1;

    if (words > 0) begin
      // Word index 0x40 corresponds to byte address 0x100.
      $readmemh(prog_path, mem, 0, words - 1);
    end

    repeat (3) @(posedge clk);
    #1 rst_n = 1'b1;

    retired = 0;
    while (retired < steps) begin
      @(posedge clk);
      #1;
      if (retire) begin
        retired = retired + 1;
      end
    end
    // Let the retirement's side effects settle.
    repeat (2) @(posedge clk);
    #1;

    fd = $fopen(out_path, "w");
    if (fd == 0) begin
      $display("FAIL: cannot open %0s", out_path);
      $fatal(1);
    end
    $fdisplay(fd, "psw %016h", psw);
    for (int i = 0; i < 16; i++) begin
      $fdisplay(fd, "gpr %0d %08h", i, gpr_dbg[32*i +: 32]);
    end
    $fdisplay(fd, "mem %06h %08h", 32'h000028, mem[32'h28 >> 2]);
    $fdisplay(fd, "mem %06h %08h", 32'h00002C, mem[32'h2C >> 2]);
    for (int w = 0; w < 16; w++) begin
      int idx;
      idx = (32'h200 >> 2) + w;
      $fdisplay(fd, "mem %06h %08h", 32'h000200 + 4 * w, mem[idx]);
    end
    $fdisplay(fd, "int %0d %0d", int_taken, int_code_dbg);
    $fclose(fd);
    $finish;
  end

  initial begin
    #2_000_000;
    $display("FAIL: oracle testbench timeout");
    $fatal(1);
  end

endmodule
