// Sony S-DSP (SNES sound generator). Eight BRR voices with gaussian
// interpolation, ADSR/GAIN envelopes, noise, pitch modulation and an 8-tap
// echo FIR. The chip runs a fixed 32-phase schedule per 32 kHz sample; one
// phase per `tick` (1.024 MHz, the S-SMP bus cycle). Each phase's steps run as
// micro-ops on the master clock right after the tick, using at most
// MAX_UOPS clocks, so the shared audio RAM port is free for the S-SMP for the
// rest of the phase. See spec/spec.md.
module sony_s_dsp (
    input  logic clk,
    input  logic rst_n,
    input  logic tick,                 // phase advance; S-SMP bus-cycle end
    // S-SMP register window ($F2/$F3); writes take effect at tick
    input  logic [6:0] reg_addr,
    input  logic reg_wr,
    input  logic [7:0] reg_wdata,
    output logic [7:0] reg_rdata,
    // S-SMP audio-RAM port: write at tick, read data valid at tick
    input  logic [15:0] smp_addr,
    input  logic smp_wr,
    input  logic [7:0] smp_wdata,
    output logic [7:0] smp_rdata,
    // external 64 KB audio SRAM, one-clock registered read
    output logic [15:0] ram_addr,
    output logic ram_we,
    output logic [7:0] ram_wdata,
    input  logic [7:0] ram_rdata,
    // 32 kHz stereo output
    output logic sample_valid,
    output logic signed [15:0] sample_l,
    output logic signed [15:0] sample_r,
    output logic [4:0] phase_o,
    output logic overrun_o             // a phase's micro-ops were still running at tick
);
`include "sony_s_dsp_gauss.svh"
`include "sony_s_dsp_sched.svh"

    localparam logic [1:0] M_RELEASE = 2'd0, M_ATTACK = 2'd1, M_DECAY = 2'd2, M_SUSTAIN = 2'd3;

    // ---------------- helpers ----------------
    function automatic logic signed [31:0] sx16(input logic [15:0] a);
        return {{16{a[15]}}, a};
    endfunction
    function automatic logic signed [31:0] sx8(input logic [7:0] a);
        return {{24{a[7]}}, a};
    endfunction
    function automatic logic signed [15:0] clamp16(input logic signed [31:0] x);
        if (x > 32'sd32767) return 16'sh7fff;
        if (x < -32'sd32768) return 16'sh8000;
        return x[15:0];
    endfunction

    function automatic logic [11:0] rate_period(input logic [4:0] r);
        case (r)
            5'd1: return 2048; 5'd2: return 1536; 5'd3: return 1280; 5'd4: return 1024;
            5'd5: return 768;  5'd6: return 640;  5'd7: return 512;  5'd8: return 384;
            5'd9: return 320;  5'd10: return 256; 5'd11: return 192; 5'd12: return 160;
            5'd13: return 128; 5'd14: return 96;  5'd15: return 80;  5'd16: return 64;
            5'd17: return 48;  5'd18: return 40;  5'd19: return 32;  5'd20: return 24;
            5'd21: return 20;  5'd22: return 16;  5'd23: return 12;  5'd24: return 10;
            5'd25: return 8;   5'd26: return 6;   5'd27: return 5;   5'd28: return 4;
            5'd29: return 3;   5'd30: return 2;   5'd31: return 1;
            default: return 1;
        endcase
    endfunction
    function automatic logic [10:0] rate_offset(input logic [4:0] r);
        if (r == 0 || r >= 5'd30) return 0;
        case (r % 3)
            0: return 536;
            1: return 0;
            default: return 1040;
        endcase
    endfunction

    // ---------------- state ----------------
    logic [7:0] regs [128];

    logic [15:0] vbuf [96];          // decoded samples (already doubled)
    logic [3:0] boff [8];               // next decode position in vbuf
    logic [15:0] goff [8];              // interpolation position (0x1000 = 1 sample)
    logic [15:0] baddr [8];             // current BRR block
    logic [3:0] bofs [8];               // byte offset in block (1..8)
    logic [2:0] kdelay [8];             // key-on setup countdown
    logic [1:0] emode [8];
    logic [10:0] env [8];
    logic [6:0] envx_v [8];
    logic [7:0] env_hi;                 // last computed envelope >= 0x600 (GAIN mode 7)
    logic [7:0] keylatch, kon_l, koff_l, mod_l, noise_l, echo_l, endx, looped;

    logic [7:0] bank_l, src_l, brr_hdr, brr_byte;
    logic [15:0] brr_addr, brr_next, nyb;
    logic [7:0] l_adsr0, l_envx, l_outx, elo;
    logic [14:0] l_pitch;
    logic [15:0] l_out;

    logic [15:0] ehist [16];
    logic [2:0] ehoff;
    logic [7:0] e_page;
    logic e_ro;
    logic [15:0] e_addr, e_off, e_len;
    logic [16:0] e_in [2];
    logic [15:0] e_out [2], m_out [2];

    logic sample_ph;
    logic [14:0] lfsr;
    logic [10:0] pcnt [32];             // (counter + offset) mod period, per rate

    logic [4:0] phase;
    logic [3:0] slot;
    logic run;

    logic [8:0] sx;
    uop_t op;
    logic [2:0] v;
    assign sx = sched(phase, slot);
    assign op = uop_t'(sx[8:3]);
    assign v = sx[2:0];
    assign phase_o = phase;
    assign reg_rdata = regs[reg_addr];
    assign smp_rdata = ram_rdata;

    function automatic logic [6:0] vr(input logic [2:0] vv, input logic [3:0] r);
        return {vv, r};
    endfunction

    function automatic logic [6:0] bi(input logic [2:0] vv, input logic [3:0] j);
        return 7'(vv * 12) + 7'(j);
    endfunction
    function automatic logic [3:0] hi(input logic c, input logic [2:0] j);
        return {c, j};
    endfunction

    logic [15:0] ea22;
    assign ea22 = {e_page, 8'h00} + e_off;

    // ---------------- audio RAM port ----------------
    always_comb begin
        ram_addr = smp_addr;
        ram_we = tick & smp_wr;
        ram_wdata = smp_wdata;
        if (run && !tick) begin
            case (op)
                U_V2A: ram_addr = brr_addr + (kdelay[v] == 0 ? 16'd2 : 16'd0);
                U_V2B: ram_addr = brr_addr + (kdelay[v] == 0 ? 16'd3 : 16'd1);
                U_V3BA: ram_addr = baddr[v] + {12'h0, bofs[v]};
                U_V3BB: ram_addr = baddr[v];
                U_V4A: ram_addr = baddr[v] + {12'h0, bofs[v]} + 16'd1;
                U_E22A: ram_addr = ea22;
                U_E22B: ram_addr = e_addr + 16'd1;
                U_E23A: ram_addr = e_addr + 16'd2;
                U_E23B: ram_addr = e_addr + 16'd3;
                U_E29A: begin ram_addr = e_addr;         ram_we = !e_ro; ram_wdata = e_out[0][7:0];  end
                U_E29B: begin ram_addr = e_addr + 16'd1; ram_we = !e_ro; ram_wdata = e_out[0][15:8]; end
                U_E30A: begin ram_addr = e_addr + 16'd2; ram_we = !e_ro; ram_wdata = e_out[1][7:0];  end
                U_E30B: begin ram_addr = e_addr + 16'd3; ram_we = !e_ro; ram_wdata = e_out[1][15:8]; end
                default: ;
            endcase
        end
    end

    // ---------------- datapath pieces ----------------
    function automatic logic [15:0] brr_sample(input logic [3:0] nib, input logic [7:0] hdr,
                                                input logic [15:0] p1r, input logic [15:0] p2r);
        logic signed [31:0] s, p1, p2;
        s = {{28{nib[3]}}, nib};
        if (hdr[7:4] <= 4'd12) begin
            s = s <<< hdr[7:4];
            s = s >>> 1;
        end else begin
            s = s & ~32'sh7ff;
        end
        p1 = sx16(p1r);
        p2 = sx16(p2r) >>> 1;
        case (hdr[3:2])
            2'd1: begin
                s = s + (p1 >>> 1);
                s = s + ((-p1) >>> 5);
            end
            2'd2: begin
                s = s + p1 - p2 + (p2 >>> 4);
                s = s + ((p1 * -3) >>> 6);
            end
            2'd3: begin
                s = s + p1 - p2;
                s = s + ((p1 * -13) >>> 7);
                s = s + ((p2 * 3) >>> 4);
            end
            default: ;
        endcase
        s = sx16(clamp16(s));
        return {s[14:0], 1'b0};
    endfunction

    function automatic logic [3:0] wrap12(input logic [4:0] i);
        return i >= 5'd12 ? 4'(i - 5'd12) : i[3:0];
    endfunction

    function automatic logic signed [31:0] gmul(input logic [10:0] g, input logic [15:0] smp);
        return ($signed({21'h0, g}) * sx16(smp)) >>> 11;
    endfunction

    function automatic logic signed [31:0] fir(input logic [15:0] h, input logic [7:0] c);
        return (sx16(h) * sx8(c)) >>> 6;
    endfunction

    function automatic logic signed [15:0] echo_out(input logic [15:0] m, input logic [7:0] mv,
                                                    input logic [16:0] e, input logic [7:0] ev);
        logic signed [31:0] a, b;
        a = (sx16(m) * sx8(mv)) >>> 7;
        b = ({{15{e[16]}}, e} * sx8(ev)) >>> 7;
        return clamp16(sx16(a[15:0]) + sx16(b[15:0]));
    endfunction

    // Rate counters, and their next values (the noise poll uses the ticked counter).
    logic [10:0] pcnt_n [32];
    always_comb begin
        for (int r = 0; r < 32; r++)
            pcnt_n[r] = pcnt[r] == 0 ? 11'(rate_period(5'(r)) - 12'd1) : pcnt[r] - 11'd1;
    end

    // Envelope step for voice v (envelopeRun).
    logic [10:0] er_env;
    logic [1:0] er_mode;
    logic er_hi;
    always_comb begin
        logic signed [31:0] e;
        logic [4:0] rate;
        logic [7:0] ed;
        logic [2:0] gm;
        e = {21'h0, env[v]};
        er_mode = emode[v];
        er_hi = env_hi[v];
        er_env = env[v];
        rate = 0;
        ed = regs[vr(v, 4'h6)];
        gm = regs[vr(v, 4'h7)][7:5];
        if (emode[v] == M_RELEASE) begin
            e = e - 8;
            if (e < 0) e = 0;
            er_env = e[10:0];
        end else begin
            if (l_adsr0[7]) begin
                if (emode[v] >= M_DECAY) begin
                    e = e - 1;
                    e = e - (e >>> 8);
                    rate = ed[4:0];
                    if (emode[v] == M_DECAY) rate = {1'b1, l_adsr0[6:4], 1'b0};
                end else begin
                    rate = {l_adsr0[3:0], 1'b1};
                    e = e + (rate < 5'd31 ? 32'sh20 : 32'sh400);
                end
            end else begin
                ed = regs[vr(v, 4'h7)];
                if (gm < 3'd4) begin
                    e = {20'h0, ed, 4'h0};
                    rate = 5'd31;
                end else begin
                    rate = ed[4:0];
                    if (gm == 3'd4) e = e - 32'sh20;
                    else if (gm == 3'd5) begin
                        e = e - 1;
                        e = e - (e >>> 8);
                    end else begin
                        e = e + 32'sh20;
                        if (gm == 3'd7 && env_hi[v]) e = e + 32'sh8 - 32'sh20;
                    end
                end
            end
            if ((e >>> 8) == {29'h0, ed[7:5]} && er_mode == M_DECAY) er_mode = M_SUSTAIN;
            er_hi = $unsigned(e) >= 32'h600;
            if ($unsigned(e) > 32'h7ff) begin
                e = e < 0 ? 32'sh0 : 32'sh7ff;
                if (er_mode == M_ATTACK) er_mode = M_DECAY;
            end
            if (rate != 0 && pcnt[rate] == 0) er_env = e[10:0];
        end
    end

    // Voice phase 3c: key-on setup, interpolation, envelope application.
    logic [14:0] c_pitch;
    logic [2:0] c_kd;
    logic [15:0] c_goff;
    logic [3:0] c_boff;
    logic [10:0] c_env;
    logic [1:0] c_mode;
    logic [7:0] c_hdr;
    logic [15:0] c_out;
    logic [6:0] c_envx;
    always_comb begin
        logic signed [31:0] p, o, smp;
        logic [7:0] g8;
        logic [3:0] i0, i1, i2, i3;
        p = {17'h0, l_pitch};
        if (mod_l[v]) p = p + (((sx16(l_out) >>> 5) * p) >>> 10);
        c_pitch = p[14:0];
        c_kd = kdelay[v];
        c_goff = goff[v];
        c_boff = boff[v];
        c_env = env[v];
        c_mode = emode[v];
        c_hdr = brr_hdr;
        if (c_kd != 0) begin
            if (c_kd == 3'd5) begin
                c_boff = 0;
                c_hdr = 0;
            end
            c_env = 0;
            c_kd = c_kd - 3'd1;
            c_goff = (c_kd[1:0] != 0) ? 16'h4000 : 16'h0000;
            c_pitch = 0;
        end
        g8 = c_goff[11:4];
        i0 = wrap12({1'b0, c_boff} + {2'b0, c_goff[14:12]});
        i1 = wrap12({1'b0, i0} + 5'd1);
        i2 = wrap12({1'b0, i1} + 5'd1);
        i3 = wrap12({1'b0, i2} + 5'd1);
        o = gmul(gauss(9'd255 - {1'b0, g8}), vbuf[bi(v, i0)])
          + gmul(gauss(9'd511 - {1'b0, g8}), vbuf[bi(v, i1)])
          + gmul(gauss(9'd256 + {1'b0, g8}), vbuf[bi(v, i2)]);
        o = sx16(o[15:0]);
        o = o + gmul(gauss({1'b0, g8}), vbuf[bi(v, i3)]);
        smp = sx16(clamp16(o) & 16'hfffe);
        if (noise_l[v]) smp = sx16({lfsr, 1'b0});
        o = (smp * $signed({21'h0, c_env})) >>> 11;
        c_out = o[15:0] & 16'hfffe;
        c_envx = c_env[10:4];
        if (regs[7'h6c][7] || c_hdr[1:0] == 2'b01) begin
            c_mode = M_RELEASE;
            c_env = 0;
        end
        if (sample_ph) begin
            if (koff_l[v]) c_mode = M_RELEASE;
            if (kon_l[v]) begin
                c_kd = 3'd5;
                c_mode = M_ATTACK;
            end
        end
    end

    // Voice output accumulation for channel ch.
    function automatic logic signed [31:0] amp(input logic [15:0] out, input logic [7:0] vol);
        return (sx16(out) * sx8(vol)) >>> 7;
    endfunction

    // ---------------- sequencer ----------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 64; i++) begin
                regs[i] <= 8'h00;
                regs[i + 64] <= 8'h00;
            end
            regs[7'h6c] <= 8'he0;
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 12; j++) vbuf[i * 12 + j] <= 16'h0;
                boff[i] <= 0; goff[i] <= 0; baddr[i] <= 0; bofs[i] <= 4'd1;
                kdelay[i] <= 0; emode[i] <= M_RELEASE; env[i] <= 0; envx_v[i] <= 0;
            end
            for (int c = 0; c < 2; c++) begin
                for (int j = 0; j < 8; j++) ehist[c * 8 + j] <= 16'h0;
                e_in[c] <= 0; e_out[c] <= 0; m_out[c] <= 0;
            end
            for (int r = 0; r < 32; r++) pcnt[r] <= 11'({1'b0, rate_offset(5'(r))} % rate_period(5'(r)));
            {env_hi, keylatch, kon_l, koff_l, mod_l, noise_l, echo_l, endx, looped} <= '0;
            {bank_l, src_l, brr_hdr, brr_byte, brr_addr, brr_next, nyb} <= '0;
            {l_adsr0, l_envx, l_outx, elo, l_pitch, l_out} <= '0;
            {ehoff, e_page, e_addr, e_off, e_len} <= '0;
            e_ro <= 1'b1;
            sample_ph <= 1'b1;
            lfsr <= 15'h4000;
            phase <= 5'd31;
            slot <= 0;
            run <= 1'b0;
            sample_valid <= 1'b0;
            sample_l <= 0;
            sample_r <= 0;
            overrun_o <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            if (tick) begin
                if (run) overrun_o <= 1'b1;
                phase <= phase + 5'd1;
                slot <= 0;
                run <= 1'b1;
                if (reg_wr) begin
                    regs[reg_addr] <= reg_wdata;
                    if (reg_addr == 7'h4c) keylatch <= reg_wdata;
                    if (reg_addr == 7'h7c) begin
                        endx <= 8'h00;
                        regs[7'h7c] <= 8'h00;
                    end
                    if (reg_addr[3:0] == 4'h8) l_envx <= reg_wdata;
                    if (reg_addr[3:0] == 4'h9) l_outx <= reg_wdata;
                end
            end else if (run) begin
                slot <= slot + 4'd1;
                case (op)
                    U_END: run <= 1'b0;
                    U_V1: begin
                        brr_addr <= {bank_l, 8'h00} + {6'h0, src_l, 2'b00};
                        src_l <= regs[vr(v, 4'h4)];
                    end
                    U_V2B: brr_next[7:0] <= ram_rdata;
                    U_V2C: begin
                        brr_next[15:8] <= ram_rdata;
                        l_adsr0 <= regs[vr(v, 4'h5)];
                        l_pitch <= {7'h0, regs[vr(v, 4'h2)]};
                    end
                    U_V3A: l_pitch <= l_pitch | {1'b0, regs[vr(v, 4'h3)][5:0], 8'h00};
                    U_V3BB: brr_byte <= ram_rdata;
                    U_V3BC: brr_hdr <= ram_rdata;
                    U_V3C1: begin
                        if (kdelay[v] == 3'd5) begin
                            baddr[v] <= brr_next;
                            bofs[v] <= 4'd1;
                        end
                        if (kdelay[v] != 0) env_hi[v] <= 1'b0;
                        l_pitch <= c_pitch;
                        kdelay[v] <= c_kd;
                        goff[v] <= c_goff;
                        boff[v] <= c_boff;
                        env[v] <= c_env;
                        emode[v] <= c_mode;
                        brr_hdr <= c_hdr;
                        l_out <= c_out;
                        envx_v[v] <= c_envx;
                    end
                    U_V3C2: if (kdelay[v] == 0) begin
                        env[v] <= er_env;
                        emode[v] <= er_mode;
                        if (emode[v] != M_RELEASE) env_hi[v] <= er_hi;
                    end
                    U_V4A: looped[v] <= 1'b0;
                    U_V4B, U_V4C, U_V4D, U_V4E: if (goff[v] >= 16'h4000) begin
                        logic [15:0] n;
                        n = op == U_V4B ? {brr_byte, ram_rdata} : nyb;
                        nyb <= {n[11:0], 4'h0};
                        vbuf[bi(v, boff[v])] <= brr_sample(n[15:12], brr_hdr,
                            vbuf[bi(v, boff[v] == 0 ? 4'd11 : boff[v] - 4'd1)],
                            vbuf[bi(v, boff[v] == 0 ? 4'd10 : boff[v] == 1 ? 4'd11 : boff[v] - 4'd2)]);
                        boff[v] <= boff[v] == 4'd11 ? 4'd0 : boff[v] + 4'd1;
                    end
                    U_V4F: begin
                        logic [16:0] g;
                        if (goff[v] >= 16'h4000) begin
                            if (bofs[v] + 4'd2 >= 4'd9) begin
                                baddr[v] <= brr_hdr[0] ? brr_next : baddr[v] + 16'd9;
                                looped[v] <= brr_hdr[0];
                                bofs[v] <= 4'd1;
                            end else begin
                                bofs[v] <= bofs[v] + 4'd2;
                            end
                        end
                        g = {3'b0, goff[v][13:0]} + {2'b0, l_pitch};
                        goff[v] <= g > 17'h7fff ? 16'h7fff : g[15:0];
                        m_out[0] <= clamp16(sx16(m_out[0]) + amp(l_out, regs[vr(v, 4'h0)]));
                        if (echo_l[v]) e_out[0] <= clamp16(sx16(e_out[0]) + amp(l_out, regs[vr(v, 4'h0)]));
                    end
                    U_V5: begin
                        m_out[1] <= clamp16(sx16(m_out[1]) + amp(l_out, regs[vr(v, 4'h1)]));
                        if (echo_l[v]) e_out[1] <= clamp16(sx16(e_out[1]) + amp(l_out, regs[vr(v, 4'h1)]));
                        endx[v] <= kdelay[v] == 3'd5 ? 1'b0 : endx[v] | looped[v];
                    end
                    U_V6: l_outx <= l_out[15:8];
                    U_V7: begin
                        regs[7'h7c] <= endx;
                        l_envx <= {1'b0, envx_v[v]};
                    end
                    U_V8: regs[vr(v, 4'h9)] <= l_outx;
                    U_V9: regs[vr(v, 4'h8)] <= l_envx;
                    U_E22A: begin
                        ehoff <= ehoff + 3'd1;
                        e_addr <= ea22;
                    end
                    U_E22B, U_E23B: elo <= ram_rdata;
                    U_E22C: begin
                        logic signed [31:0] s;
                        s = sx16({ram_rdata, elo}) >>> 1;
                        ehist[hi(1'b0, ehoff)] <= s[15:0];
                        e_in[0] <= 17'(fir(ehist[hi(1'b0, ehoff + 3'd1)], regs[7'h0f]));
                        e_in[1] <= 17'(fir(ehist[hi(1'b1, ehoff + 3'd1)], regs[7'h0f]));
                    end
                    U_E23C: begin
                        logic signed [31:0] s;
                        s = sx16({ram_rdata, elo}) >>> 1;
                        ehist[hi(1'b1, ehoff)] <= s[15:0];
                        for (int c = 0; c < 2; c++)
                            e_in[c] <= e_in[c] + 17'(fir(ehist[hi(1'(c), ehoff + 3'd2)], regs[7'h1f])
                                                   + fir(ehist[hi(1'(c), ehoff + 3'd3)], regs[7'h2f]));
                    end
                    U_E24: for (int c = 0; c < 2; c++)
                        e_in[c] <= e_in[c] + 17'(fir(ehist[hi(1'(c), ehoff + 3'd4)], regs[7'h3f])
                                               + fir(ehist[hi(1'(c), ehoff + 3'd5)], regs[7'h4f])
                                               + fir(ehist[hi(1'(c), ehoff + 3'd6)], regs[7'h5f]));
                    U_E25: for (int c = 0; c < 2; c++) begin
                        logic signed [31:0] s, f7;
                        s = {{15{e_in[c][16]}}, e_in[c]} + fir(ehist[hi(1'(c), ehoff + 3'd7)], regs[7'h6f]);
                        f7 = fir(ehist[hi(1'(c), ehoff)], regs[7'h7f]);
                        s = sx16(s[15:0]) + sx16(f7[15:0]);
                        e_in[c] <= 17'(sx16(clamp16(s) & 16'hfffe));
                    end
                    U_E26: begin
                        m_out[0] <= echo_out(m_out[0], regs[7'h0c], e_in[0], regs[7'h2c]);
                        for (int c = 0; c < 2; c++) begin
                            logic signed [31:0] fb;
                            fb = ({{15{e_in[c][16]}}, e_in[c]} * sx8(regs[7'h0d])) >>> 7;
                            e_out[c] <= clamp16(sx16(e_out[c]) + sx16(fb[15:0])) & 16'hfffe;
                        end
                    end
                    U_E27: begin
                        sample_valid <= 1'b1;
                        sample_l <= regs[7'h6c][6] ? 16'sh0 : m_out[0];
                        sample_r <= regs[7'h6c][6] ? 16'sh0 : echo_out(m_out[1], regs[7'h1c], e_in[1], regs[7'h3c]);
                        m_out[0] <= 0;
                        m_out[1] <= 0;
                    end
                    U_E28: e_ro <= regs[7'h6c][5];
                    U_E29A: begin
                        logic [15:0] len, no;
                        e_page <= regs[7'h6d];
                        len = e_off == 0 ? {1'b0, regs[7'h7d][3:0], 11'h0} : e_len;
                        e_len <= len;
                        no = e_off + 16'd4;
                        e_off <= no >= len ? 16'h0 : no;
                    end
                    U_E29B: begin
                        e_out[0] <= 0;
                        e_ro <= regs[7'h6c][5];
                    end
                    U_E30B: e_out[1] <= 0;
                    U_M27: mod_l <= regs[7'h2d] & 8'hfe;
                    U_M28: begin
                        noise_l <= regs[7'h3d];
                        echo_l <= regs[7'h4d];
                        bank_l <= regs[7'h5d];
                    end
                    U_M29: begin
                        sample_ph <= !sample_ph;
                        if (!sample_ph) keylatch <= keylatch & ~kon_l;
                    end
                    U_M30: begin
                        if (sample_ph) begin
                            kon_l <= keylatch;
                            koff_l <= regs[7'h5c];
                        end
                        for (int r = 0; r < 32; r++) pcnt[r] <= pcnt_n[r];
                        if (regs[7'h6c][4:0] != 0 && pcnt_n[regs[7'h6c][4:0]] == 0)
                            lfsr <= {lfsr[0] ^ lfsr[1], lfsr[14:1]};
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
