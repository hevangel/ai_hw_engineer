`timescale 1ns/1ps
module tb_top;
  logic cp_i = 0;
  logic rst_n = 1;
  logic pe_n_i = 0;
  logic j_i = 0;
  logic k_n_i = 0;
  logic [3:0] p_i = 0;
  logic [3:0] q_o;
  logic q3_n_o;
  logic [3:0] cascade_q;
  logic cascade_q3_n;
  logic [7:0] chain_expected;
  logic [3:0] expected;
  integer checks = 0;
  integer transitions = 0;
  integer reset_checks = 0;
  integer cascade_checks = 0;
  logic [15:0] seen_parallel = 0;
  logic [3:0] seen_jk = 0;

  amd_am9300 dut (.*);
  amd_am9300 cascade (
      .cp_i(cp_i), .rst_n(rst_n), .pe_n_i(pe_n_i),
      .j_i(q_o[3]), .k_n_i(q_o[3]), .p_i(p_i),
      .q_o(cascade_q), .q3_n_o(cascade_q3_n)
  );

  task automatic check(input logic [3:0] want, input string label_text);
    checks++;
    if (q_o !== want || q3_n_o !== ~want[3])
      $fatal(1, "%s: got Q=%h Q3bar=%b expected=%h at %0t",
             label_text, q_o, q3_n_o, want, $time);
  endtask

  task automatic pulse;
    cp_i = 0;
    #2;
    cp_i = 1;
    #2;
  endtask

  task automatic load(input logic [3:0] value);
    cp_i = 0;
    pe_n_i = 0;
    p_i = value;
    pulse();
    check(value, "prepare prior state");
    cp_i = 0;
    #2;
  endtask

  initial begin
    #1;
    rst_n = 0;
    #1;
    check(0, "initial asynchronous MR");
    rst_n = 1;
    #1;
    for (integer state_value = 0; state_value < 16; state_value++) begin
      for (integer mode_value = 0; mode_value < 2; mode_value++) begin
        for (integer jk_value = 0; jk_value < 4; jk_value++) begin
          for (integer parallel_value = 0; parallel_value < 16; parallel_value++) begin
            load(4'(state_value));
            pe_n_i = 1'(mode_value);
            {j_i, k_n_i} = 2'(jk_value);
            p_i = 4'(parallel_value);
            expected = 4'(state_value);
            #1;
            check(expected, "data changes with low CP");
            if (!pe_n_i) begin
              expected = p_i;
              seen_parallel[parallel_value] = 1;
            end else begin
              expected[3:1] = 3'(state_value);
              // Independent physical pin truth table: do not reuse RTL equation.
              case (jk_value)
                0: expected[0] = 0;
                1: expected[0] = 1'(state_value);
                2: expected[0] = !1'(state_value);
                3: expected[0] = 1;
              endcase
              seen_jk[jk_value] = 1;
            end
            pulse();
            check(expected, "exhaustive transition");
            transitions++;
            p_i = ~p_i;
            j_i = ~j_i;
            k_n_i = ~k_n_i;
            pe_n_i = ~pe_n_i;
            #1;
            check(expected, "data changes with held-high CP");
            cp_i = 0;
            #1;
            check(expected, "falling CP holds");
          end
        end
      end
    end

    for (integer level_value = 0; level_value < 2; level_value++) begin
      for (integer state_value = 0; state_value < 16; state_value++) begin
        load(4'(state_value));
        cp_i = 1'(level_value);
        #2;
        rst_n = 0;
        #1;
        check(0, "MR clears between rising clocks");
        reset_checks++;
        pe_n_i = 0;
        p_i = 4'hf;
        j_i = 1;
        k_n_i = 1;
        pulse();
        check(0, "MR dominates parallel load");
        pe_n_i = 1;
        pulse();
        check(0, "MR dominates serial mode");
        rst_n = 1;
        #1;
        check(0, "MR release with high CP holds");
        load(4'ha);
      end
    end

    load(0);
    chain_expected = 0;
    pe_n_i = 1;
    for (integer bit_index = 0; bit_index < 64; bit_index++) begin
      cp_i = 0;
      j_i = ((bit_index % 7) < 3);
      k_n_i = j_i;
      chain_expected = {chain_expected[6:0], j_i};
      pulse();
      check(chain_expected[3:0], "serial D stream");
      if (cascade_q !== chain_expected[7:4] ||
          cascade_q3_n !== ~chain_expected[7])
        $fatal(1, "cascade captured new Q3 instead of old Q3");
      cascade_checks++;
    end
    if (transitions != 2048 || reset_checks != 32 || cascade_checks != 64 ||
        seen_parallel != 16'hffff || seen_jk != 4'hf)
      $fatal(1, "incomplete functional coverage");
    $display("TEST PASSED: %0d checks, %0d transitions, %0d resets, %0d cascade shifts; 0 failures",
             checks, transitions, reset_checks, cascade_checks);
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "test watchdog expired");
  end
endmodule
