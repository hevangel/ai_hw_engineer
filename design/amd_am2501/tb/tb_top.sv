`timescale 1ns/1ps
module tb_top;
  logic cp_i = 0;
  logic cd_n_i = 1;
  logic pe_n_i = 0;
  logic [5:0] ce_i = 0;
  logic [3:0] p_i = 0;
  logic [3:0] q_o;
  logic tc_o;
  logic [3:0] q_two;
  logic tc_two;
  logic [3:0] expected_six, expected_two;
  integer checks = 0;
  integer transitions = 0;
  integer chain_checks = 0;
  localparam logic [63:0] UP_STATES = 64'h0fedcba987654321;
  localparam logic [63:0] DOWN_STATES = 64'hedcba9876543210f;

  logic chain_cp = 0;
  logic chain_dir = 1;
  logic chain_pe = 0;
  logic chain_enable = 0;
  logic [15:0] chain_p = 0;
  logic [3:0] chain_q [0:3];
  logic [3:0] chain_tc;
  logic [5:0] chain_ce [0:3];
  logic [15:0] expected_chain;

  amd_am2501 dut (.*);
  amd_am2501 #(.CE_INPUTS(2)) two_ce (
      .cp_i(cp_i), .cd_n_i(cd_n_i), .pe_n_i(pe_n_i), .ce_i(ce_i[1:0]),
      .p_i(p_i), .q_o(q_two), .tc_o(tc_two)
  );
  // Manufacturer Fig. 9: TC outputs feed separate look-ahead CE inputs.
  assign chain_ce[0] = {5'b11111, chain_enable};
  assign chain_ce[1] = {4'b1111, chain_tc[0], chain_enable};
  assign chain_ce[2] = {3'b111, chain_tc[1:0], chain_enable};
  assign chain_ce[3] = {2'b11, chain_tc[2:0], chain_enable};
  for (genvar slice = 0; slice < 4; slice++) begin : g_chain
    amd_am2501 counter (
        .cp_i(chain_cp), .cd_n_i(chain_dir), .pe_n_i(chain_pe),
        .ce_i(chain_ce[slice]), .p_i(chain_p[4*slice +: 4]),
        .q_o(chain_q[slice]), .tc_o(chain_tc[slice])
    );
  end

  task automatic check_pair(input logic [3:0] want_six, want_two, input string tag);
    checks++;
    if (q_o !== want_six || q_two !== want_two ||
        tc_o !== (cd_n_i ? want_six == 15 : want_six == 0) ||
        tc_two !== (cd_n_i ? want_two == 15 : want_two == 0))
      $fatal(1, "%s: six=%h expected=%h two=%h expected=%h TC=%b/%b",
             tag, q_o, want_six, q_two, want_two, tc_o, tc_two);
  endtask

  task automatic pulse;
    #1;
    cp_i = 0;
    #2;
    cp_i = 1;
    #1;
  endtask

  task automatic check_chain;
    chain_checks++;
    if ({chain_q[3],chain_q[2],chain_q[1],chain_q[0]} !== expected_chain)
      $fatal(1, "look-ahead cascade mismatch: expected %h got %h%h%h%h",
             expected_chain,chain_q[3],chain_q[2],chain_q[1],chain_q[0]);
    for (integer slice = 0; slice < 4; slice++) begin
      if (chain_tc[slice] !== (chain_dir ? chain_q[slice] == 15 : chain_q[slice] == 0))
        $fatal(1, "cascade terminal count mismatch");
    end
  endtask

  task automatic chain_pulse;
    #1;
    chain_cp = 0;
    #2;
    chain_cp = 1;
    #1;
  endtask

  initial begin
    // First real CP presets both packages; there is no reset.
    pulse();
    check_pair(0, 0, "initial synchronous preset");
    for (integer state_value = 0; state_value < 16; state_value++) begin
      for (integer dir_value = 0; dir_value < 2; dir_value++) begin
        for (integer mode_value = 0; mode_value < 2; mode_value++) begin
          for (integer ce_value = 0; ce_value < 64; ce_value++) begin
            for (integer p_value = 0; p_value < 16; p_value++) begin
              // All controls update in the datasheet's CP-HIGH window.
              pe_n_i = 0;
              p_i = 4'(state_value);
              pulse();
              cd_n_i = 1'(dir_value);
              pe_n_i = 1'(mode_value);
              ce_i = 6'(ce_value);
              p_i = 4'(p_value);
              expected_six = 4'(state_value);
              expected_two = 4'(state_value);
              #1;
              check_pair(expected_six, expected_two, "held-high CP and TC direction decode");
              cp_i = 0;
              #1;
              check_pair(expected_six, expected_two, "falling CP holds");
              if (!pe_n_i) begin
                expected_six = p_i;
                expected_two = p_i;
              end else begin
                if (ce_value == 63)
                  expected_six = cd_n_i ? UP_STATES[4*state_value +: 4] : DOWN_STATES[4*state_value +: 4];
                if ((ce_value & 3) == 3)
                  expected_two = cd_n_i ? UP_STATES[4*state_value +: 4] : DOWN_STATES[4*state_value +: 4];
              end
              #1;
              cp_i = 1;
              #1;
              check_pair(expected_six, expected_two, "exhaustive state transition");
              transitions++;
            end
          end
        end
      end
    end

    expected_chain = 0;
    chain_pulse();
    check_chain();
    chain_pe = 1;
    chain_enable = 1;
    for (integer step = 0; step < 65540; step++) begin
      expected_chain = expected_chain + 16'd1;
      chain_pulse();
      check_chain();
    end
    chain_dir = 0;
    for (integer step = 0; step < 65540; step++) begin
      expected_chain = expected_chain - 16'd1;
      chain_pulse();
      check_chain();
    end
    chain_enable = 0;
    for (integer step = 0; step < 4; step++) begin
      chain_pulse();
      check_chain();
    end
    chain_pe = 0;
    chain_p = 16'hffff;
    expected_chain = chain_p;
    chain_pulse();
    check_chain();
    chain_dir = 1;
    chain_pe = 1;
    chain_pulse();
    check_chain();
    if (transitions != 65536 || chain_checks != 131087)
      $fatal(1, "incomplete functional coverage %0d/%0d", transitions,chain_checks);
    $display("TEST PASSED: %0d pair checks, %0d exhaustive transitions, %0d cascade checks; 0 failures",
             checks, transitions, chain_checks);
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "test watchdog expired");
  end
endmodule
