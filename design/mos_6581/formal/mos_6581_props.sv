// Structural invariants of the SID digital core with free CPU, POT and
// pull-down inputs. Waveform/envelope values are qualified by the oracle.
logic past_valid = 1'b0;
always_ff @(posedge clk) begin
    past_valid <= 1;
    if (!past_valid) assume (!rst_n);
    if (past_valid && rst_n) begin
        for (int i = 0; i < 3; i++) begin
            assert (state_q[i] != 2'd3 && next_q[i] != 2'd3);
            assert (env_pipe_q[i] <= 3'd4 && exp_pipe_q[i] <= 2'd2 && pipe_q[i] <= 2'd2);
            assert (exp_period_q[i] == 5'd1 || exp_period_q[i] == 5'd2 || exp_period_q[i] == 5'd4 ||
                    exp_period_q[i] == 5'd8 || exp_period_q[i] == 5'd16 || exp_period_q[i] == 5'd30);
            assert (new_period_q[i] == 5'd0 || new_period_q[i] == 5'd1 || new_period_q[i] == 5'd2 ||
                    new_period_q[i] == 5'd4 || new_period_q[i] == 5'd8 ||
                    new_period_q[i] == 5'd16 || new_period_q[i] == 5'd30);
            // The rate LFSR never reaches the all-zero lock-up state.
            assert (lfsr_q[i] != 0);
            // The test bit holds the accumulator at zero.
            if (test_q[i]) assert (acc_q[i] == 0);
            assert (sustain_q[i][7:4] == sustain_q[i][3:0]);
            assert (pulse_q[i] == 12'h000 || pulse_q[i] == 12'hfff);
        end
        assert (ttl_q <= 20'(BUS_TTL));
        // Holds freeze oscillators and envelopes (CPU writes excepted).
        if ($past(rst_n && !ce_i && !cs_i)) begin
            assert (acc_q == $past(acc_q) && env_q == $past(env_q) && lfsr_q == $past(lfsr_q));
        end
        cover (state_q[0] == ST_ATTACK && env_q[0] != 8'haa);
        cover (pd_sel_o[1] != 0);
        cover (test_q[2] && sr_reset_q[2] != 0);
        cover (any_sync);
        cover (ttl_q != 0 && $past(ttl_q) == ttl_q + 20'd1);
    end
    if (past_valid && !$past(rst_n)) begin
        assert (acc_q == {3{24'h555555}} && env_q == {3{8'haa}} && ttl_q == 0);
    end
end
