// MOS 6581 / 8580 SID digital core: registers, three oscillators with
// noise/pulse/ring/sync, envelope generators, OSC3/ENV3/POT reads and the
// decaying data-bus latch. Behavior follows the pinned reSIDfp digital model
// (spec/spec.md). The analog pull-down of combined waveforms is supplied by
// an external sampled table interface; the filter, DACs and mixer are a
// separate analog stage.
module mos_6581 #(
    parameter bit MOS8580 = 1'b0
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce_i,          // one SID system clock (phase two)
    input  logic        cs_i,
    input  logic        rw_i,
    input  logic [4:0]  addr_i,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    input  logic [7:0]  pot_x_i,
    input  logic [7:0]  pot_y_i,
    // Combined-waveform pull-down lookups (select 0 = none, else table+1).
    output logic [2:0][2:0]  pd_sel_o,
    output logic [2:0][11:0] pd_index_o,
    input  logic [2:0][11:0] pd_value_i,
    output logic [11:0] osc3_pd_index_o,
    input  logic [11:0] osc3_pd_value_i,
    // Digital voice outputs for the analog stage.
    output logic [2:0][11:0] wave_o,
    output logic [2:0][7:0]  env_o,
    output logic [10:0] fc_o,
    output logic [7:0]  res_filt_o,
    output logic [7:0]  mode_vol_o
);
    localparam int FLOATING_TTL = MOS8580 ? 800000 : 54000;
    localparam int FLOATING_FADE = MOS8580 ? 50000 : 1400;
    localparam int SR_RESET = MOS8580 ? 986000 : 50000;
    localparam int SR_FADE = MOS8580 ? 314300 : 15000;
    localparam int BUS_TTL = MOS8580 ? 'ha2000 : 'h1d00;
    // Clears the eight noise tap bits 2, 4, 8, 11, 13, 17, 20 and 22.
    localparam logic [22:0] SHIFT_MASK = ~23'h522914;
    localparam logic [1:0] ST_ATTACK = 2'd0, ST_DECAY = 2'd1, ST_RELEASE = 2'd2;

    function automatic logic [14:0] adsr_rate(input logic [3:0] i);
        case (i)
            4'h0: adsr_rate = 15'h007f;  4'h1: adsr_rate = 15'h3000;
            4'h2: adsr_rate = 15'h1e00;  4'h3: adsr_rate = 15'h0660;
            4'h4: adsr_rate = 15'h0182;  4'h5: adsr_rate = 15'h5573;
            4'h6: adsr_rate = 15'h000e;  4'h7: adsr_rate = 15'h3805;
            4'h8: adsr_rate = 15'h2424;  4'h9: adsr_rate = 15'h2220;
            4'ha: adsr_rate = 15'h090c;  4'hb: adsr_rate = 15'h0ecd;
            4'hc: adsr_rate = 15'h010e;  4'hd: adsr_rate = 15'h23f7;
            4'he: adsr_rate = 15'h5237;  default: adsr_rate = 15'h64a8;
        endcase
    endfunction

    // Noise output taps eight shift-register bits; the rest only shift.
    /* verilator lint_off UNUSEDSIGNAL */
    function automatic logic [11:0] noise_bits(input logic [22:0] sr);
        noise_bits = {sr[2], sr[4], sr[8], sr[11], sr[13], sr[17], sr[20], sr[22], 4'h0};
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */

    function automatic logic [22:0] noise_writeback(input logic [7:0] w);  // waveform bits 11..4
        noise_writeback = '0;
        noise_writeback[2] = w[7];
        noise_writeback[4] = w[6];
        noise_writeback[8] = w[5];
        noise_writeback[11] = w[4];
        noise_writeback[13] = w[3];
        noise_writeback[17] = w[2];
        noise_writeback[20] = w[1];
        noise_writeback[22] = w[0];
    endfunction

    function automatic logic do_writeback(input logic [3:0] old_w, input logic [3:0] new_w);
        do_writeback = 1;
        if (old_w <= 4'd8) do_writeback = 0;
        else if (new_w < 4'd8) do_writeback = 0;
        else if (new_w == 4'd8 && old_w != 4'hf) do_writeback = 0;
        else if (!MOS8580 && ((old_w[1:0] == 2'b01 && new_w[1:0] == 2'b10) ||
                              (old_w[1:0] == 2'b10 && new_w[1:0] == 2'b01))) do_writeback = 0;
        else if (old_w == 4'hc) do_writeback = 0;
        else if (new_w == 4'hc) do_writeback = 0;
    endfunction

    function automatic logic [11:0] base_wave(input logic [1:0] sel, input logic [11:0] ix);
        logic [11:0] tri_v;
        tri_v = ix[11] ? {ix[10:0] ^ 11'h7ff, 1'b0} : {ix[10:0], 1'b0};
        case (sel)
            2'd0: base_wave = 12'hfff;
            2'd1: base_wave = tri_v;
            2'd2: base_wave = ix;
            default: base_wave = ix & {ix[10:0], 1'b0};
        endcase
    endfunction

    function automatic logic [2:0] pulldown_select(input logic [3:0] w);
        case (w[2:0])
            3'd3: pulldown_select = 3'd1;
            3'd4: pulldown_select = w[3] ? 3'd5 : 3'd0;
            3'd5: pulldown_select = 3'd2;
            3'd6: pulldown_select = 3'd3;
            3'd7: pulldown_select = 3'd4;
            default: pulldown_select = 3'd0;
        endcase
    endfunction

    // ------------------------------------------------------------ voice state
    logic [2:0][23:0] acc_q, acc_d;
    logic [2:0][15:0] freq_q, freq_d;
    logic [2:0][11:0] pw_q, pw_d;
    logic [2:0][22:0] sr_q, sr_d, latch_q, latch_d;
    logic [2:0][1:0]  pipe_q, pipe_d;
    logic [2:0]       ring_q, ring_d, nonoise_q, nonoise_d, nopulse_q, nopulse_d;
    logic [2:0][11:0] noise_q, noise_d, pulse_q, pulse_d, wout_q, wout_d;
    logic [2:0][11:0] trisaw_q, trisaw_d, osc3_q, osc3_d;
    logic [2:0][21:0] sr_reset_q, sr_reset_d;
    logic [2:0][19:0] float_q, float_d;
    logic [2:0][3:0]  wave_sel_q, wave_sel_d;
    logic [2:0]       test_q, test_d, sync_q, sync_d, tor_q, tor_d, msb_q, msb_d;
    // Envelope state.
    logic [2:0][14:0] lfsr_q, lfsr_d, rate_q, rate_d;
    logic [2:0][15:0] exp_q, exp_d;
    logic [2:0][4:0]  exp_period_q, exp_period_d, new_period_q, new_period_d;
    logic [2:0][1:0]  state_pipe_q, state_pipe_d;
    logic [2:0][2:0]  env_pipe_q, env_pipe_d;
    logic [2:0][1:0]  exp_pipe_q, exp_pipe_d;
    logic [2:0][1:0]  state_q, state_d, next_q, next_d;
    logic [2:0]       enabled_q, enabled_d, gate_q, gate_d, reset_lfsr_q, reset_lfsr_d;
    logic [2:0][7:0]  env_q, env_d, env3_q, env3_d, sustain_q, sustain_d;
    logic [2:0][3:0]  attack_q, attack_d, decay_q, decay_d, release_q, release_d;
    // Bus latch and filter registers.
    logic [7:0]  bus_q, bus_d;
    logic [19:0] ttl_q, ttl_d;
    logic [10:0] fc_q, fc_d;
    logic [7:0]  res_q, res_d, mode_q, mode_d;

    logic [11:0] ix, base, pd_in, masked;
    logic        old23, old19;
    logic        rise23, rise19;
    logic [45:0] phase2;
    logic [2:0]  rose;
    logic [3:0]  wprev, wnew;
    logic        tprev, any_sync, env_hit, exp_hit;
    logic [1:0]  v;
    logic [2:0]  sel, fld;
    logic [4:0]  fld5;
    logic [23:0] ring_acc;
    logic [7:0]  read_value;
    logic [14:0] feedback;
    int          prev_v, next_v;

    // Shift phase two (also on a falling test bit): optional write-back,
    // then shift in (bit22 | test/reset) ^ bit17. Returns {latch, register}.
    function automatic logic [45:0] shift_phase2(
        input logic [22:0] sr, input logic [22:0] latch, input logic [7:0] w,
        input logic tor, input logic [3:0] old_w, input logic [3:0] new_w
    );
        logic [22:0] l;
        l = latch;
        if (do_writeback(old_w, new_w))
            l = (sr & SHIFT_MASK) | noise_writeback(w);
        shift_phase2 = {l, (tor | l[0]) ^ l[5], l[22:1]};
    endfunction

    // Exponential decay period selected by envelope counter thresholds.
    function automatic logic [4:0] exponential_period(input logic [7:0] env,
                                                      input logic [4:0] current);
        case (env)
            8'hff, 8'h00: exponential_period = 5'd1;
            8'h5d: exponential_period = 5'd2;
            8'h36: exponential_period = 5'd4;
            8'h1a: exponential_period = 5'd8;
            8'h0e: exponential_period = 5'd16;
            8'h06: exponential_period = 5'd30;
            default: exponential_period = current;
        endcase
    endfunction

    always_comb begin
        acc_d = acc_q;  freq_d = freq_q;  pw_d = pw_q;  sr_d = sr_q;  latch_d = latch_q;
        pipe_d = pipe_q;  ring_d = ring_q;  nonoise_d = nonoise_q;  nopulse_d = nopulse_q;
        noise_d = noise_q;  pulse_d = pulse_q;  wout_d = wout_q;  trisaw_d = trisaw_q;
        osc3_d = osc3_q;  sr_reset_d = sr_reset_q;  float_d = float_q;  wave_sel_d = wave_sel_q;
        test_d = test_q;  sync_d = sync_q;  tor_d = tor_q;  msb_d = msb_q;
        lfsr_d = lfsr_q;  rate_d = rate_q;  exp_d = exp_q;  exp_period_d = exp_period_q;
        new_period_d = new_period_q;  state_pipe_d = state_pipe_q;  env_pipe_d = env_pipe_q;
        exp_pipe_d = exp_pipe_q;  state_d = state_q;  next_d = next_q;  enabled_d = enabled_q;
        gate_d = gate_q;  reset_lfsr_d = reset_lfsr_q;  env_d = env_q;  env3_d = env3_q;
        sustain_d = sustain_q;  attack_d = attack_q;  decay_d = decay_q;  release_d = release_q;
        bus_d = bus_q;  ttl_d = ttl_q;  fc_d = fc_q;  res_d = res_q;  mode_d = mode_q;
        pd_sel_o = '0;  pd_index_o = '0;  osc3_pd_index_o = 0;
        ix = 0;  base = 0;  sel = 0;  fld = 0;  fld5 = 0;  ring_acc = 0;  pd_in = 0;  masked = 0;  old23 = 0;  old19 = 0;  rise23 = 0;  rise19 = 0;  phase2 = 0;  rose = 0;
        wprev = 0;  wnew = 0;  tprev = 0;  any_sync = 0;  env_hit = 0;  exp_hit = 0;  v = 0;  feedback = 0;
        prev_v = 0;  next_v = 0;

        // ---- CPU access (completes before the cycle it accompanies)
        read_value = bus_q;
        if (rw_i) begin
            case (addr_i)
                5'h19: read_value = pot_x_i;
                5'h1a: read_value = pot_y_i;
                5'h1b: read_value = osc3_q[2][11:4];
                5'h1c: read_value = env3_q[2];
                default: read_value = bus_q;
            endcase
        end
        data_o = read_value;

        if (rst_n && cs_i) begin
            if (rw_i) begin
                if (addr_i >= 5'h19 && addr_i <= 5'h1c) begin
                    bus_d = read_value;
                    ttl_d = 20'(BUS_TTL);
                end else begin
                    // Reading a write-only register discharges the bus faster.
                    ttl_d = {1'b0, ttl_d[19:1]};
                end
            end else begin
                bus_d = data_i;
                ttl_d = 20'(BUS_TTL);
                if (addr_i < 5'h15) begin
                    v = (addr_i >= 5'd14) ? 2'd2 : (addr_i >= 5'd7) ? 2'd1 : 2'd0;
                    fld5 = addr_i - 5'd7 * {3'd0, v};
                    fld = fld5[2:0];
                    case (fld)
                        0: freq_d[v][7:0] = data_i;
                        1: freq_d[v][15:8] = data_i;
                        2: pw_d[v][7:0] = data_i;
                        3: pw_d[v][11:8] = data_i[3:0];
                        4: begin
                            // Waveform generator control.
                            wprev = wave_sel_d[v];
                            tprev = test_d[v];
                            wnew = data_i[7:4];
                            wave_sel_d[v] = wnew;
                            test_d[v] = data_i[3];
                            sync_d[v] = data_i[1];
                            ring_d[v] = !data_i[5] && data_i[2];
                            if (wnew != wprev) begin
                                nonoise_d[v] = !wnew[3];
                                nopulse_d[v] = !wnew[2];
                                if (wnew == 0) float_d[v] = 20'(FLOATING_TTL);
                            end
                            if (test_d[v] != tprev) begin
                                if (test_d[v]) begin
                                    acc_d[v] = 0;
                                    pipe_d[v] = 0;
                                    latch_d[v] = sr_d[v];
                                    sr_reset_d[v] = 22'(SR_RESET);
                                end else begin
                                    phase2 = shift_phase2(sr_d[v], latch_d[v], wout_d[v][11:4],
                                                          tor_d[v], wprev, wnew);
                                    latch_d[v] = phase2[45:23];
                                    sr_d[v] = phase2[22:0];
                                    noise_d[v] = noise_bits(sr_d[v]);
                                end
                            end
                            // Envelope gate.
                            if (data_i[0] != gate_d[v]) begin
                                gate_d[v] = data_i[0];
                                if (data_i[0]) begin
                                    next_d[v] = ST_ATTACK;
                                    state_pipe_d[v] = 2'd2;
                                    if (reset_lfsr_d[v] || exp_pipe_d[v] == 2'd2) begin
                                        env_pipe_d[v] = (exp_period_d[v] == 5'd1 || exp_pipe_d[v] == 2'd2) ?
                                                        3'd2 : 3'd4;
                                    end else if (exp_pipe_d[v] == 2'd1) begin
                                        state_pipe_d[v] = 2'd3;
                                    end
                                end else begin
                                    next_d[v] = ST_RELEASE;
                                    state_pipe_d[v] = (env_pipe_d[v] != 0) ? 2'd3 : 2'd2;
                                end
                            end
                        end
                        5: begin
                            attack_d[v] = data_i[7:4];
                            decay_d[v] = data_i[3:0];
                            if (state_d[v] == ST_ATTACK) rate_d[v] = adsr_rate(data_i[7:4]);
                            else if (state_d[v] == ST_DECAY) rate_d[v] = adsr_rate(data_i[3:0]);
                        end
                        default: begin
                            sustain_d[v] = {data_i[7:4], data_i[7:4]};
                            release_d[v] = data_i[3:0];
                            if (state_d[v] == ST_RELEASE) rate_d[v] = adsr_rate(data_i[3:0]);
                        end
                    endcase
                end else if (addr_i == 5'h15) begin
                    fc_d[2:0] = data_i[2:0];
                end else if (addr_i == 5'h16) begin
                    fc_d[10:3] = data_i;
                end else if (addr_i == 5'h17) begin
                    res_d = data_i;
                end else if (addr_i == 5'h18) begin
                    mode_d = data_i;
                end
            end
        end

        if (rst_n && ce_i) begin
            // ---- bus latch ageing
            if (ttl_d != 0) begin
                ttl_d = ttl_d - 20'd1;
                if (ttl_d == 0) bus_d = 0;
            end

            // ---- oscillators
            for (int i = 0; i < 3; i++) begin
                if (test_d[i]) begin
                    if (sr_reset_d[i] != 0) begin
                        sr_reset_d[i] = sr_reset_d[i] - 22'd1;
                        if (sr_reset_d[i] == 0) begin
                            sr_d[i] = sr_d[i] | {1'b0, sr_d[i][22:1]};
                            sr_d[i][22] = 1;
                            if (sr_d[i] != 23'h7fffff) sr_reset_d[i] = 22'(SR_FADE);
                            latch_d[i] = sr_d[i];
                            noise_d[i] = noise_bits(sr_d[i]);
                        end
                    end
                    tor_d[i] = 1;
                    pulse_d[i] = 12'hfff;
                end else begin
                    old23 = acc_d[i][23];
                    old19 = acc_d[i][19];
                    acc_d[i] = acc_d[i] + {8'h00, freq_d[i]};
                    rise23 = !old23 && acc_d[i][23];
                    rise19 = !old19 && acc_d[i][19];
                    msb_d[i] = rise23;
                    rose[i] = rise23;
                    if (rise19) begin
                        pipe_d[i] = 2'd2;
                    end else if (pipe_d[i] != 0) begin
                        pipe_d[i] = pipe_d[i] - 2'd1;
                        if (pipe_d[i] == 0) begin
                            phase2 = shift_phase2(sr_d[i], latch_d[i], wout_d[i][11:4],
                                                  tor_d[i], wave_sel_d[i], wave_sel_d[i]);
                            latch_d[i] = phase2[45:23];
                            sr_d[i] = phase2[22:0];
                            noise_d[i] = noise_bits(sr_d[i]);
                        end else begin
                            tor_d[i] = 0;
                            latch_d[i] = sr_d[i];
                        end
                    end
                end
            end

            // ---- envelope generators
            for (int i = 0; i < 3; i++) begin
                env3_d[i] = env_d[i];
                if (new_period_d[i] != 0) begin
                    exp_period_d[i] = new_period_d[i];
                    new_period_d[i] = 0;
                end
                if (state_pipe_d[i] != 0) begin
                    state_pipe_d[i] = state_pipe_d[i] - 2'd1;
                    case (next_d[i])
                        ST_ATTACK: begin
                            if (state_pipe_d[i] == 2'd1) begin
                                rate_d[i] = adsr_rate(decay_d[i]);
                            end else if (state_pipe_d[i] == 2'd0) begin
                                state_d[i] = ST_ATTACK;
                                rate_d[i] = adsr_rate(attack_d[i]);
                                enabled_d[i] = 1;
                            end
                        end
                        ST_DECAY: begin
                            if (state_pipe_d[i] == 2'd0) begin
                                state_d[i] = ST_DECAY;
                                rate_d[i] = adsr_rate(decay_d[i]);
                            end
                        end
                        default: begin
                            if ((state_d[i] == ST_ATTACK && state_pipe_d[i] == 2'd0) ||
                                (state_d[i] == ST_DECAY && state_pipe_d[i] == 2'd1)) begin
                                state_d[i] = ST_RELEASE;
                                rate_d[i] = adsr_rate(release_d[i]);
                            end
                        end
                    endcase
                end
                // Pipelines count down; a branch fires when its counter
                // reaches zero, otherwise evaluation falls through.
                env_hit = 0;
                exp_hit = 0;
                if (env_pipe_d[i] != 0) begin
                    env_pipe_d[i] = env_pipe_d[i] - 3'd1;
                    env_hit = env_pipe_d[i] == 0;
                end
                if (!env_hit && exp_pipe_d[i] != 0) begin
                    exp_pipe_d[i] = exp_pipe_d[i] - 2'd1;
                    exp_hit = exp_pipe_d[i] == 0;
                end
                if (env_hit) begin
                    if (enabled_d[i]) begin
                        if (state_d[i] == ST_ATTACK) begin
                            env_d[i] = env_d[i] + 8'd1;
                            if (env_d[i] == 8'hff) begin
                                next_d[i] = ST_DECAY;
                                state_pipe_d[i] = 2'd3;
                            end
                        end else if (state_d[i] == ST_DECAY || state_d[i] == ST_RELEASE) begin
                            env_d[i] = env_d[i] - 8'd1;
                            if (env_d[i] == 8'h00) enabled_d[i] = 0;
                        end
                        new_period_d[i] = exponential_period(env_d[i], new_period_d[i]);
                    end
                end else if (exp_hit) begin
                    exp_d[i] = 0;
                    if ((state_d[i] == ST_DECAY && env_d[i] != sustain_d[i]) ||
                        state_d[i] == ST_RELEASE)
                        env_pipe_d[i] = 3'd1;
                end else if (reset_lfsr_d[i]) begin
                    lfsr_d[i] = 15'h7fff;
                    reset_lfsr_d[i] = 0;
                    if (state_d[i] == ST_ATTACK) begin
                        exp_d[i] = 0;
                        env_pipe_d[i] = 3'd2;
                    end else if (enabled_d[i]) begin
                        exp_d[i] = exp_d[i] + 16'd1;
                        if (exp_d[i] == {11'd0, exp_period_d[i]})
                            exp_pipe_d[i] = (exp_period_d[i] != 5'd1) ? 2'd2 : 2'd1;
                    end
                end
                // ADSR delay bug: the 15-bit LFSR keeps running until it
                // matches the rate, wrapping around when the rate decreased.
                if (lfsr_d[i] != rate_d[i]) begin
                    feedback = ((lfsr_d[i] << 14) ^ (lfsr_d[i] << 13)) & 15'h4000;
                    lfsr_d[i] = {1'b0, lfsr_d[i][14:1]} | feedback;
                end else begin
                    reset_lfsr_d[i] = 1;
                end
            end

            // ---- waveform outputs, in voice order (ring uses the previous voice)
            for (int i = 0; i < 3; i++) begin
                prev_v = (i + 2) % 3;
                if (wave_sel_d[i] != 0) begin
                    ring_acc = acc_d[i] ^ ({ring_d[i], 23'd0} & ~acc_d[prev_v]);
                    ix = ring_acc[23:12];
                    base = base_wave(wave_sel_d[i][1:0], ix);
                    masked = base & (nopulse_d[i] ? 12'hfff : pulse_d[i]) &
                             (nonoise_d[i] ? 12'hfff : noise_d[i]);
                    sel = pulldown_select(wave_sel_d[i]);
                    pd_sel_o[i] = sel;
                    pd_index_o[i] = masked;
                    wout_d[i] = (sel != 0) ? pd_value_i[i] : masked;
                    if (MOS8580 && wave_sel_d[i][1:0] != 0) begin
                        pd_in = trisaw_d[i] & (nopulse_d[i] ? 12'hfff : pulse_d[i]) &
                                (nonoise_d[i] ? 12'hfff : noise_d[i]);
                        if (i == 2) osc3_pd_index_o = pd_in;
                        osc3_d[i] = (sel != 0) ? (i == 2 ? osc3_pd_value_i : pd_in) : pd_in;
                        trisaw_d[i] = base;
                    end else begin
                        osc3_d[i] = wout_d[i];
                    end
                    if (!MOS8580 && wave_sel_d[i][1] && !wout_d[i][11]) begin
                        msb_d[i] = 0;
                        acc_d[i][23] = 0;
                    end
                    // Combined waveforms with noise write back into the shift register.
                    if (wave_sel_d[i] > 4'd8) begin
                        if (pipe_d[i] != 2'd1 && !test_d[i]) begin
                            sr_d[i] = sr_d[i] & (SHIFT_MASK | noise_writeback(wout_d[i][11:4]));
                            noise_d[i] = noise_d[i] & wout_d[i];
                        end else begin
                            noise_d[i] = wout_d[i];
                        end
                    end
                end else if (float_d[i] != 0) begin
                    // Floating DAC input fades bit by bit.
                    float_d[i] = float_d[i] - 20'd1;
                    if (float_d[i] == 0) begin
                        wout_d[i] = wout_d[i] & {1'b0, wout_d[i][11:1]};
                        osc3_d[i] = wout_d[i];
                        if (wout_d[i] != 0) float_d[i] = 20'(FLOATING_FADE);
                    end
                end
                pulse_d[i] = (acc_d[i][23:12] >= pw_d[i]) ? 12'hfff : 12'h000;
            end

            // ---- hard sync when an eligible oscillator's MSB rose
            any_sync = 0;
            for (int i = 0; i < 3; i++) begin
                next_v = (i + 1) % 3;
                if (rose[i] && !test_d[i] && freq_d[i] != 0 && sync_d[next_v]) any_sync = 1;
            end
            if (any_sync) begin
                for (int i = 0; i < 3; i++) begin
                    next_v = (i + 1) % 3;
                    prev_v = (i + 2) % 3;
                    if (msb_d[i] && sync_d[next_v] && !(sync_d[i] && msb_d[prev_v]))
                        acc_d[next_v] = 0;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization equals reSIDfp construction
        // plus reset(): accumulators at the even-bit power-up pattern, the
        // envelope counter at $AA, the shift register clocked once from all
        // ones, release state with the LFSR pending a reset.
        if (!rst_n) begin
            acc_q <= {3{24'h555555}};
            freq_q <= '0;  pw_q <= '0;
            sr_q <= {3{23'h3fffff}};
            latch_q <= {3{23'h7fffff}};
            pipe_q <= '0;  ring_q <= '0;  nonoise_q <= '1;  nopulse_q <= '1;
            noise_q <= {3{noise_bits(23'h3fffff)}};
            pulse_q <= {3{12'hfff}};  wout_q <= '0;  trisaw_q <= {3{12'h555}};  osc3_q <= '0;
            sr_reset_q <= '0;  float_q <= '0;  wave_sel_q <= '0;
            test_q <= '0;  sync_q <= '0;  tor_q <= '1;  msb_q <= '0;
            lfsr_q <= {3{15'h7fff}};  rate_q <= {3{15'h007f}};  exp_q <= '0;
            exp_period_q <= {3{5'd1}};  new_period_q <= '0;
            state_pipe_q <= '0;  env_pipe_q <= '0;  exp_pipe_q <= '0;
            state_q <= {3{ST_RELEASE}};  next_q <= {3{ST_RELEASE}};
            enabled_q <= '1;  gate_q <= '0;  reset_lfsr_q <= '1;
            env_q <= {3{8'haa}};  env3_q <= '0;  sustain_q <= '0;
            attack_q <= '0;  decay_q <= '0;  release_q <= '0;
            bus_q <= 0;  ttl_q <= 0;  fc_q <= 0;  res_q <= 0;  mode_q <= 0;
        end else begin
            acc_q <= acc_d;  freq_q <= freq_d;  pw_q <= pw_d;  sr_q <= sr_d;  latch_q <= latch_d;
            pipe_q <= pipe_d;  ring_q <= ring_d;  nonoise_q <= nonoise_d;  nopulse_q <= nopulse_d;
            noise_q <= noise_d;  pulse_q <= pulse_d;  wout_q <= wout_d;  trisaw_q <= trisaw_d;
            osc3_q <= osc3_d;  sr_reset_q <= sr_reset_d;  float_q <= float_d;
            wave_sel_q <= wave_sel_d;  test_q <= test_d;  sync_q <= sync_d;  tor_q <= tor_d;
            msb_q <= msb_d;  lfsr_q <= lfsr_d;  rate_q <= rate_d;  exp_q <= exp_d;
            exp_period_q <= exp_period_d;  new_period_q <= new_period_d;
            state_pipe_q <= state_pipe_d;  env_pipe_q <= env_pipe_d;  exp_pipe_q <= exp_pipe_d;
            state_q <= state_d;  next_q <= next_d;  enabled_q <= enabled_d;  gate_q <= gate_d;
            reset_lfsr_q <= reset_lfsr_d;  env_q <= env_d;  env3_q <= env3_d;
            sustain_q <= sustain_d;  attack_q <= attack_d;  decay_q <= decay_d;
            release_q <= release_d;  bus_q <= bus_d;  ttl_q <= ttl_d;
            fc_q <= fc_d;  res_q <= res_d;  mode_q <= mode_d;
        end
    end

    // Field arithmetic and sub-index accumulator bits are not outputs.
    logic unused_bits;
    assign unused_bits = ^{fld5[4:3], ring_acc[11:0]};

    assign wave_o = wout_q;
    assign env_o = env_q;
    assign fc_o = fc_q;
    assign res_filt_o = res_q;
    assign mode_vol_o = mode_q;

`ifdef FORMAL
    `include "mos_6581_props.sv"
`endif
endmodule
