// amd_am9518_top.sv — AMD Am9518 / AmZ8068 Data Ciphering Processor.
//
// Functional reconstruction per spec/spec.md.  Primary interface is the
// Multiplexed Control Mode (C/K low): register address MP2/MP1 and chip
// select latch on rising MAS edges; write data is captured on rising MDS
// edges; read data is driven while MCS, MR/W and MDS are low.  Direct
// Control Mode (C/K high) exposes the AUX5-S/S, AUX6-E/D, AUX7-K/D control
// lines and AUX2-BSY / AUX3-CP status mirrors on the auxiliary port.
//
// Reconstruction-only signals (not device pins):
//   rst_i  — power-on reset convenience input (the real part resets from a
//            VCC-threshold pulse internally)
//   *_in / *_out / *_oe — the three tri-state master/slave/aux buses are
//            modeled as input, output and output-enable for simulation and
//            SoC integration.

`default_nettype none

module amd_am9518_top (
    input  logic       clk,
    input  logic       rst_i,

    // Master port (pins 16-19, 21-24).
    input  logic [7:0] mp_in,
    output logic [7:0] mp_out,
    output logic       mp_oe,
    input  logic       mcs_n,
    input  logic       mas_n,
    input  logic       mds_n,
    input  logic       mr_w_n,
    input  logic       ck,          // C/K: 0 = multiplexed, 1 = direct
    output logic       mflg_n,

    // Slave port (pins 2-5, 39-36).
    input  logic [7:0] sp_in,
    output logic [7:0] sp_out,
    output logic       sp_oe,
    input  logic       scs_n,
    input  logic       sds_n,
    output logic       sflg_n,

    // Auxiliary port (pins 6-9, 32-35).
    input  logic [7:0] aux_in,
    output logic [7:0] aux_out,
    output logic       aux_oe,
    input  logic       astb_n,
    output logic       aflg_n,

    output logic       par_n        // pin 12: low = parity error
);

    `include "amd_am9518_defs.svh"

    // ------------------------------------------------------------------
    // Strobe synchronization (A3): two flops per strobe; actions run on
    // detected rising edges at the following clock edge.
    // ------------------------------------------------------------------
    logic mas_s0, mas_s1, mds_s0, mds_s1, sds_s0, sds_s1, astb_s0, astb_s1;
    always_ff @(posedge clk) begin
        if (rst_i) begin
            mas_s0 <= 1'b1;  mas_s1  <= 1'b1;
            mds_s0 <= 1'b1;  mds_s1  <= 1'b1;
            sds_s0 <= 1'b1;  sds_s1  <= 1'b1;
            astb_s0 <= 1'b1; astb_s1 <= 1'b1;
        end else begin
            mas_s0  <= mas_n;   mas_s1  <= mas_s0;
            mds_s0  <= mds_n;   mds_s1  <= mds_s0;
            sds_s0  <= sds_n;   sds_s1  <= sds_s0;
            astb_s0 <= astb_n;  astb_s1 <= astb_s0;
        end
    end
    // s0 is the newer sample; a synchronized rising edge is s0=1, s1=0.
    wire logic mas_rise  = mas_s0 & ~mas_s1;
    wire logic mds_rise  = mds_s0 & ~mds_s1;
    wire logic sds_rise  = sds_s0 & ~sds_s1;
    wire logic astb_rise = astb_s0 & ~astb_s1;

    // Hardware reset: MAS and MDS low simultaneously (p. 2-463/2-466).
    wire logic hw_reset = ~mas_s1 & ~mds_s1;

    // ------------------------------------------------------------------
    // Reset modes and the post-reset command blackout (A11).
    // ------------------------------------------------------------------
    logic soft_reset;           // one-cycle pulse from command/mode writes
    logic soft_keep_mode;       // mode-register write keeps its new value
    logic blackout;
    logic [2:0] blackout_cnt;

    // ------------------------------------------------------------------
    // Chip select / address latching (multiplexed mode only).
    // ------------------------------------------------------------------
    logic mcs_latched_n;
    logic [1:0] addr_latched;   // {MP2, MP1}
    always_ff @(posedge clk) begin
        if (rst_i | hw_reset) begin
            mcs_latched_n <= 1'b1;
            addr_latched  <= 2'b00;
        end else if (mas_rise && !ck) begin
            mcs_latched_n <= mcs_n;
            addr_latched  <= mp_in[2:1];
        end
    end
    // While MAS is low the latch is transparent (p. 2-463 MCS).
    wire logic mcs_int_n = ck ? mcs_n :
                           (mas_s1 ? mcs_latched_n : mcs_n);

    // Register select decode (datasheet Figure 1).
    logic [2:0] sel;
    always_comb begin
        sel = SEL_NONE;
        if (mcs_int_n == 1'b0) begin
            if (!ck) begin
                if (addr_latched[0] == 1'b0)           // MP1 = 0
                    sel = mr_w_n ? SEL_OUTPUT : SEL_INPUT;
                else if (addr_latched[1] == 1'b0)      // MP1=1, MP2=0
                    sel = mr_w_n ? SEL_STATUS : SEL_CMD;
                else                                   // MP1=1, MP2=1
                    sel = SEL_MODE;
            end else begin
                // Direct control: master port limited to data registers.
                sel = mr_w_n ? SEL_OUTPUT : SEL_INPUT;
            end
        end
    end

    // ------------------------------------------------------------------
    // Mode register.
    // ------------------------------------------------------------------
    logic [7:0] mode_q;
    wire logic       mode_enc    = mode_q[4];
    wire logic [1:0] mode_cipher = mode_q[6:5];
    wire logic [1:0] mode_cfg    = mode_q[3:2];
    wire logic       mode_cfb    = (mode_cipher == CIPHER_CFB);
    wire logic       mode_cbc    = (mode_cipher == CIPHER_CBC);
    wire logic [3:0] block_bytes = mode_cfb ? 4'd1 : 4'd8;

    // ------------------------------------------------------------------
    // Key / IV registers.
    // ------------------------------------------------------------------
    logic [63:0] k_key_q, e_key_q, d_key_q, ive_q, ivd_q;

    // ------------------------------------------------------------------
    // Input register (push-down, MSB-first) and output register (pop-up).
    // ------------------------------------------------------------------
    logic [7:0] inp_bytes [8];
    logic [3:0] inp_cnt;
    wire logic  inp_full = (inp_cnt >= block_bytes);
    logic [3:0] inp_holdoff;         // in-flag delay after algorithm start

    logic [7:0] out_bytes [8];
    logic [3:0] out_cnt;
    wire logic  out_empty = (out_cnt == 4'd0);
    wire logic  out_full  = (out_cnt >= 4'd8);

    // Assembled input block (first byte written = MSB).
    logic [63:0] inp_block;
    always_comb begin
        for (int i = 0; i < 8; i++)
            inp_block[63 - 8*i -: 8] = inp_bytes[i];
    end

    // ------------------------------------------------------------------
    // Command processor.
    // ------------------------------------------------------------------
    typedef enum logic [2:0] {
        CS_IDLE    = 3'd0,
        CS_COLLECT = 3'd1,   // gathering 8 bytes into cmd_buf
        CS_DEC     = 3'd2,   // DES-decrypting cmd_buf into the target
        CS_ENC_OUT = 3'd3,   // DES-encrypting a register to the output path
        CS_PUMP    = 3'd4,   // output register holds 8 command bytes
        CS_IVDLY   = 3'd5,   // six-clock delay before Read-Clear-IV pump
        CS_EMK     = 3'd6    // collecting 8 bytes via the input register
    } cmd_state_t;

    cmd_state_t cs;
    logic       cmd_via_aux;         // bytes arrive on ASTB
    logic [2:0] cmd_cnt;             // bytes collected
    logic [63:0] cmd_buf;
    logic       cmd_is_key;          // target is a key register (parity)
    logic       cmd_is_iv;           // target is an IV register
    logic       cmd_is_mkey;         // target is the M (master) key register
    logic       cmd_to_dkey;         // target: D key / IVD (else E / IVE)
    logic       cmd_enc_load;        // collected bytes are decrypted first
    logic [2:0] iv_delay;
    logic [3:0] cmd_reads;           // output pops toward completion

    wire logic cmd_active = (cs != CS_IDLE);

    // ------------------------------------------------------------------
    // DES engine.
    // ------------------------------------------------------------------
    logic        dec_trig_q, encout_trig_q, emk_active_q;
    logic        dec_pend_q, encout_pend_q;   // deferred starts (engine busy)
    logic [63:0] alg_block, alg_key;
    logic        alg_key_load, alg_key_dec;

    wire logic sess_trig = s7_start & !cmd_active & !alg_busy &
                           (inp_cnt == block_bytes);
    wire logic emk_trig  = (cs == CS_EMK) & !emk_active_q & !alg_busy &
                           (inp_cnt == 4'd8);
    // Command-driven starts defer until the engine is idle (a Read-IV or
    // encrypted-load decrypt can be requested while a session block or CFB
    // byte is still mid-cipher).
    wire logic dec_go    = dec_pend_q & !alg_busy & !sess_trig & !emk_trig;
    wire logic enc_go    = encout_pend_q & !alg_busy & !sess_trig & !emk_trig
                           & !dec_go;
    wire logic alg_start = sess_trig | emk_trig | dec_go | enc_go;

    logic [63:0] alg_result;
    logic        alg_done, alg_busy;
    des_core u_des (
        .clk(clk), .rst(rst_i | hw_reset | soft_reset),
        .key_load(alg_key_load), .key_data(alg_key),
        .key_decrypt(alg_key_dec),
        .start(alg_start), .block_in(alg_block),
        .result(alg_result), .done(alg_done), .busy(alg_busy)
    );

    // Result delivery staging (5-cycle out-flag delay, p. 2-477).
    logic [63:0] deliver_buf;
    logic        deliver_pend;
    logic [2:0]  deliver_cnt;
    wire logic   chip_busy = alg_busy | deliver_pend;

    // Session chain register (CBC chaining value / CFB shift register).
    logic [63:0] chain_q;
    logic [63:0] inp_block_q;        // block/byte consumed by the running op
    wire logic [7:0] cfb_ks    = alg_result[63:56];
    wire logic [7:0] cfb_fb    = inp_block_q[63:56] ^ cfb_ks;

    // ------------------------------------------------------------------
    // Flags (datasheet Figure 4 / Figure 6).
    // ------------------------------------------------------------------
    wire logic [1:0] assoc = f_flag_assoc(mode_enc, mode_cfg);
    // Input flag: active while a started session is progressing and the
    // input register has room (A17 — anchored on AMD's published status
    // reads, which show the flag inactive once a single block has been
    // ciphered and drained).
    wire logic chip_active = alg_busy | deliver_pend | ~out_empty |
                             (inp_cnt != 4'd0);
    wire logic inp_flag = s7_start & ~inp_full & (inp_holdoff == 4'd0) &
                          !cmd_active & chip_active;
    wire logic out_flag = ~out_empty;
    // assoc[0]=1 means the input flag drives SFLG; MFLG carries the input
    // flag when assoc[0]==0.
    wire logic in_flag_is_m = (assoc[0] == 1'b0);

    logic s7_start, s6_cp, s5_busy, s4_lpar, s3_par;
    wire logic s2_aflg, s1_sflg, s0_mflg;
    assign s0_mflg = in_flag_is_m ? inp_flag : out_flag;
    assign s1_sflg = in_flag_is_m ? out_flag : inp_flag;
    assign s2_aflg = cmd_active & cmd_via_aux;
    assign s5_busy = chip_busy;
    assign mflg_n  = ~s0_mflg;
    assign sflg_n  = ~s1_sflg;

    wire logic [7:0] status_byte = {s7_start, s6_cp, s5_busy, s4_lpar,
                                    s3_par, s2_aflg, s1_sflg, s0_mflg};

    // Documentation constants from the package (status bit positions,
    // reserved encodings, pipeline timing table) are kept verbatim from the
    // datasheet; only some are structurally referenced.
    /* verilator lint_off UNUSEDPARAM */
    /* verilator lint_off UNUSEDSIGNAL */
    wire logic unused_doc_params =
        ^{CIPHER_RSV, CIPHER_ECB, CFG_ME_SC, CFG_MC_SE, CFG_SINGLE, CFG_RSV,
          ST_START, ST_CP, ST_BSY, ST_LPAR, ST_PAR, ST_AFLG, ST_SFLG,
          ST_MFLG, IN_BYTES, FLAG_DELAY, RESET_BLACKOUT, 1'b0};
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNUSEDPARAM */

    // ------------------------------------------------------------------
    // Input byte routing.
    // ------------------------------------------------------------------
    wire logic inp_push_mp = mds_rise & ~mr_w_n & ~mcs_int_n &
                             (sel == SEL_INPUT) & ~blackout &
                             ((cs == CS_COLLECT && !cmd_via_aux) ||
                              (cs == CS_EMK) ||
                              (s7_start && !cmd_active));
    wire logic inp_full_mp = (cs == CS_EMK) ? (inp_cnt >= 4'd8) : inp_full;
    wire logic inp_push_sp = sds_rise & ~scs_n & ~in_flag_is_m &
                             s7_start & !cmd_active & ~inp_full;

    // ------------------------------------------------------------------
    // Output port assignment and drive (Figure 6).
    // ------------------------------------------------------------------
    wire logic out_to_slave = (assoc[1] == 1'b1);    // output flag on SFLG

    always_comb begin
        mp_out = out_bytes[0];
        mp_oe  = 1'b0;
        if (!mcs_int_n && mr_w_n && !mds_s1 && (sel != SEL_NONE)) begin
            if (sel == SEL_STATUS) begin
                mp_out = status_byte;
                mp_oe  = 1'b1;
            end else if (sel == SEL_MODE) begin
                mp_out = mode_q;
                mp_oe  = 1'b1;
            end else if (sel == SEL_OUTPUT && !out_empty) begin
                mp_out = out_bytes[0];
                mp_oe  = 1'b1;
            end
        end
    end

    always_comb begin
        sp_out = out_bytes[0];
        sp_oe  = !scs_n && !sds_s1 && out_to_slave && !out_empty;
    end

    // Output-register pops (master read at Output address / slave read).
    wire logic out_pop_mp = mds_rise & mr_w_n & ~mcs_int_n &
                            (sel == SEL_OUTPUT) & ~out_empty;
    wire logic out_pop_sp = sds_rise & ~scs_n & out_to_slave & ~out_empty;
    wire logic out_pop    = out_pop_mp | out_pop_sp;

    // ------------------------------------------------------------------
    // Auxiliary port.
    // ------------------------------------------------------------------
    assign aux_oe  = ck;    // direct mode mirrors BSY/CP on AUX2/AUX3
    assign aux_out = {4'b0000, s6_cp, chip_busy, 2'b00};
    assign aflg_n  = ~s2_aflg;
    assign par_n   = ~s3_par;

    logic aux_prev_kd, aux_prev_ss;
    wire logic kd_rise = ck &  aux_in[7] & ~aux_prev_kd;
    wire logic kd_fall = ck & ~aux_in[7] &  aux_prev_kd;
    wire logic ss_rise = ck &  aux_in[5] & ~aux_prev_ss;
    wire logic ss_fall = ck & ~aux_in[5] &  aux_prev_ss;
    always_ff @(posedge clk) begin
        if (rst_i) begin
            aux_prev_kd <= 1'b0;
            aux_prev_ss <= 1'b0;
        end else begin
            aux_prev_kd <= aux_in[7];
            aux_prev_ss <= aux_in[5];
        end
    end

    // Odd parity required; LSB of each key byte is the parity bit.
    function automatic logic f_bad_parity(logic [7:0] b);
        f_bad_parity = ~(^b);
    endfunction

    // ==================================================================
    // DES engine key/operation muxing (combinational).
    // ==================================================================
    wire logic [63:0] sess_key = mode_enc ? e_key_q : d_key_q;
    wire logic        sess_dec = mode_cfb ? 1'b0 : ~mode_enc;   // A5

    always_comb begin
        alg_key_load = alg_start;                       // reload every op
        alg_key_dec  = sess_dec;
        alg_key      = sess_key;
        alg_block    = inp_block;                       // ECB / CBC decrypt
        if (mode_cbc && mode_enc) alg_block = inp_block ^ chain_q;
        if (mode_cfb)             alg_block = chain_q;

        if (dec_go) begin                              // A7
            alg_key_dec = 1'b1;
            alg_key     = cmd_is_iv ? d_key_q : k_key_q;
            alg_block   = cmd_buf;
        end
        if (enc_go) begin
            alg_key_dec = 1'b0;
            alg_key     = e_key_q;
            alg_block   = cmd_to_dkey ? ivd_q : ive_q;
        end
        if (emk_trig) begin
            alg_key_dec = 1'b0;
            alg_key     = k_key_q;
            alg_block   = inp_block;
        end
    end

    // ==================================================================
    // Sequential logic
    // ==================================================================
    always_ff @(posedge clk) begin
        // ---- one-cycle pulses ----
        soft_reset     <= 1'b0;
        dec_trig_q     <= 1'b0;
        encout_trig_q  <= 1'b0;

        // Deferred command-start pending flags.
        if (dec_trig_q)   dec_pend_q <= 1'b1;
        else if (dec_go)  dec_pend_q <= 1'b0;
        if (encout_trig_q) encout_pend_q <= 1'b1;
        else if (enc_go)   encout_pend_q <= 1'b0;

        if (rst_i | hw_reset) begin
            cs           <= CS_IDLE;
            emk_active_q <= 1'b0;
            dec_pend_q   <= 1'b0;
            encout_pend_q<= 1'b0;
            s7_start     <= 1'b0;
            s6_cp        <= 1'b0;
            s4_lpar      <= 1'b0;
            s3_par       <= 1'b0;
            mode_q       <= MODE_RESET;
            inp_cnt      <= 4'd0;
            out_cnt      <= 4'd0;
            inp_holdoff  <= 4'd0;
            deliver_pend <= 1'b0;
            deliver_cnt  <= 3'd0;
            blackout     <= 1'b1;
            blackout_cnt <= 3'd4;   // five-clock blackout after release
            cmd_cnt      <= 3'd0;
            cmd_reads    <= 4'd0;
            iv_delay     <= 3'd0;
            chain_q      <= 64'd0;
            k_key_q      <= 64'd0;
            e_key_q      <= 64'd0;
            d_key_q      <= 64'd0;
            ive_q        <= 64'd0;
            ivd_q        <= 64'd0;
        end else begin
            // ---- blackout countdown ----
            if (blackout) begin
                if (blackout_cnt == 3'd0) blackout <= 1'b0;
                else blackout_cnt <= blackout_cnt - 3'd1;
            end

            // ---- in-flag holdoff countdown ----
            if (inp_holdoff != 4'd0) inp_holdoff <= inp_holdoff - 4'd1;

            // ---- Read-Clear-IV six-clock delay and pump ----
            if (cs == CS_IVDLY && !blackout) begin
                if (iv_delay == 3'd0) begin
                    if (cmd_to_dkey) begin
                        for (int i = 0; i < 8; i++)
                            out_bytes[i] <= ivd_q[63 - 8*i -: 8];
                    end else begin
                        for (int i = 0; i < 8; i++)
                            out_bytes[i] <= ive_q[63 - 8*i -: 8];
                    end
                    out_cnt <= 4'd8;
                    cs      <= CS_PUMP;
                end else begin
                    iv_delay <= iv_delay - 3'd1;
                end
            end

            // ---- result delivery staging ----
            if (deliver_pend) begin
                if (deliver_cnt != 3'd0) begin
                    deliver_cnt <= deliver_cnt - 3'd1;
                end else if (out_empty) begin
                    for (int i = 0; i < 8; i++)
                        out_bytes[i] <= deliver_buf[63 - 8*i -: 8];
                    out_cnt      <= 4'd8;
                    deliver_pend <= 1'b0;
                end
                // else: keep waiting; busy stays high (p. 2-467)
            end

            // ---- output register pops ----
            if (out_pop) begin
                for (int i = 0; i < 7; i++)
                    out_bytes[i] <= out_bytes[i+1];
                out_cnt <= out_cnt - 4'd1;
                if (cs == CS_PUMP) begin
                    if (cmd_reads == 4'd7) begin   // eighth byte read
                        s6_cp    <= 1'b0;
                        cs       <= CS_IDLE;
                        cmd_reads <= 4'd0;
                    end else begin
                        cmd_reads <= cmd_reads + 4'd1;
                    end
                end
            end

            // ---- DES done handling ----
            if (alg_done) begin
                if (cs == CS_DEC) begin
                    if (cmd_is_key) begin
                        if (cmd_to_dkey) d_key_q <= alg_result;
                        else             e_key_q <= alg_result;
                        // Post-decryption parity check over all eight
                        // bytes (datasheet p. 2-469/2-470, spec A12):
                        // PAR reflects the last byte, LPAR latches any
                        // error in the load.
                        s3_par  <= f_bad_parity(alg_result[7:0]);
                        s4_lpar <= s4_lpar |
                                   (f_bad_parity(alg_result[63:56]) |
                                    f_bad_parity(alg_result[55:48]) |
                                    f_bad_parity(alg_result[47:40]) |
                                    f_bad_parity(alg_result[39:32]) |
                                    f_bad_parity(alg_result[31:24]) |
                                    f_bad_parity(alg_result[23:16]) |
                                    f_bad_parity(alg_result[15:8]) |
                                    f_bad_parity(alg_result[7:0]));
                        s6_cp   <= 1'b0;
                        cs      <= CS_IDLE;
                    end else begin
                        if (cmd_to_dkey) ivd_q <= alg_result;
                        else             ive_q <= alg_result;
                        s6_cp <= 1'b0;
                        cs    <= CS_IDLE;
                    end
                end else if (cs == CS_ENC_OUT || (cs == CS_EMK && emk_active_q)) begin
                    deliver_buf  <= alg_result;
                    deliver_pend <= 1'b1;
                    deliver_cnt  <= 3'd4;
                    cs           <= CS_PUMP;
                    emk_active_q <= 1'b0;
                    cmd_reads    <= 4'd0;
                    inp_cnt      <= 4'd0;
                end else if (!cmd_active) begin
                    // Session block (ECB/CBC) or CFB byte completed.
                    if (mode_cfb) begin
                        // Feedback byte: the cipher byte in both directions
                        // (encrypt: C_n = P_n XOR keystream = cfb_fb;
                        //  decrypt: C_n is the raw input byte).
                        logic [7:0] fb_byte;
                        fb_byte = mode_enc ? cfb_fb : inp_block_q[63:56];
                        chain_q <= {chain_q[55:0], fb_byte};
                        if (mode_enc) ive_q <= {chain_q[55:0], fb_byte};
                        else          ivd_q <= {chain_q[55:0], fb_byte};
                        if (!out_full) begin
                            out_bytes[out_cnt[2:0]] <= cfb_fb;
                            out_cnt <= out_cnt + 4'd1;
                        end
                        inp_cnt     <= 4'd0;
                        inp_holdoff <= 4'd5;
                    end else begin
                        deliver_pend <= 1'b1;
                        deliver_cnt  <= 3'd4;
                        inp_cnt      <= 4'd0;
                        inp_holdoff  <= 4'd5;
                        if (mode_cbc) begin
                            if (mode_enc) begin
                                chain_q <= alg_result;
                                ive_q   <= alg_result;
                                deliver_buf <= alg_result;
                            end else begin
                                // P_n = D(C_n) XOR C_(n-1); the old chain_q
                                // (previous block or IVD) is the XOR input.
                                chain_q     <= inp_block_q;
                                ivd_q       <= inp_block_q;
                                deliver_buf <= alg_result ^ chain_q;
                            end
                        end else begin
                            deliver_buf <= alg_result;   // ECB
                        end
                    end
                end
            end

            // ---- session/EMK engine start side effects ----
            if (sess_trig) begin
                inp_block_q <= inp_block;
                inp_cnt     <= 4'd0;
                inp_holdoff <= 4'd5;
            end
            if (emk_trig) emk_active_q <= 1'b1;

            // ---- master-port write actions ----
            if (mds_rise && !mcs_int_n && !blackout) begin
                if (sel == SEL_CMD) begin
                    if (cmd_active) begin
                        // A8/A16: aborting a command performs an internal
                        // reset with the default mode; the new byte is lost.
                        soft_reset     <= 1'b1;
                        soft_keep_mode <= 1'b0;
                    end else begin
                        s7_start <= 1'b0;  // non-Start commands clear S7
                        case (mp_in)
                            CMD_RESET: begin
                                soft_reset     <= 1'b1;
                                soft_keep_mode <= 1'b0;
                            end
                            CMD_STOP: begin
                                s7_start <= 1'b0;
                            end
                            CMD_START_ENC, CMD_START_DEC, CMD_START: begin
                                s7_start <= 1'b1;
                                if (mp_in == CMD_START_ENC) mode_q[4] <= 1'b1;
                                if (mp_in == CMD_START_DEC) mode_q[4] <= 1'b0;
                                inp_cnt     <= 4'd0;   // realign input (A15)
                                inp_holdoff <= 4'd0;
                                case (mode_cipher)
                                    CIPHER_CBC: chain_q <= mode_enc ? ive_q : ivd_q;
                                    CIPHER_CFB: chain_q <= mode_enc ? ive_q : ivd_q;
                                    default: ;
                                endcase
                            end
                            CMD_LOAD_E_CLEAR_MP, CMD_LOAD_D_CLEAR_MP,
                            CMD_LOAD_E_ENC_MP,   CMD_LOAD_D_ENC_MP,
                            CMD_LOAD_M_CLEAR_AUX, CMD_LOAD_E_CLEAR_AUX,
                            CMD_LOAD_D_CLEAR_AUX, CMD_LOAD_E_ENC_AUX,
                            CMD_LOAD_D_ENC_AUX: begin
                                cs           <= CS_COLLECT;
                                cmd_via_aux  <= (mp_in == CMD_LOAD_M_CLEAR_AUX) ||
                                                (mp_in == CMD_LOAD_E_CLEAR_AUX) ||
                                                (mp_in == CMD_LOAD_D_CLEAR_AUX) ||
                                                (mp_in == CMD_LOAD_E_ENC_AUX) ||
                                                (mp_in == CMD_LOAD_D_ENC_AUX);
                                cmd_cnt      <= 3'd0;
                                cmd_is_key   <= 1'b1;
                                cmd_is_iv    <= 1'b0;
                                // The M key has its own register and is
                                // loaded in the clear via the aux port only.
                                cmd_is_mkey  <= (mp_in == CMD_LOAD_M_CLEAR_AUX);
                                // LSB selects the session-key target:
                                // 1 = E key, 0 = D key (Figure 2 codes).
                                cmd_to_dkey  <= ~mp_in[0];
                                cmd_enc_load <= (mp_in == CMD_LOAD_E_ENC_MP) ||
                                                (mp_in == CMD_LOAD_D_ENC_MP) ||
                                                (mp_in == CMD_LOAD_E_ENC_AUX) ||
                                                (mp_in == CMD_LOAD_D_ENC_AUX);
                                s6_cp        <= 1'b1;
                                s4_lpar      <= 1'b0;
                            end
                            CMD_LOAD_IVE_CLEAR, CMD_LOAD_IVD_CLEAR,
                            CMD_LOAD_IVE_ENC, CMD_LOAD_IVD_ENC: begin
                                cs           <= CS_COLLECT;
                                cmd_via_aux  <= 1'b0;
                                cmd_cnt      <= 3'd0;
                                cmd_is_key   <= 1'b0;
                                cmd_is_iv    <= 1'b1;
                                cmd_is_mkey  <= 1'b0;
                                cmd_to_dkey  <= ~mp_in[0];   // 1 = IVE, 0 = IVD
                                // Bit 5 distinguishes encrypted (A5/A4,
                                // 1010_xxxx) from clear (85/84, 1000_xxxx).
                                cmd_enc_load <= mp_in[5];
                                s6_cp        <= 1'b1;
                            end
                            CMD_READ_IVE_CLEAR, CMD_READ_IVD_CLEAR: begin
                                cs          <= CS_IVDLY;
                                iv_delay    <= 3'd5;
                                cmd_to_dkey <= (mp_in == CMD_READ_IVD_CLEAR);
                                s6_cp       <= 1'b1;
                                cmd_reads   <= 4'd0;
                            end
                            CMD_READ_IVE_ENC, CMD_READ_IVD_ENC: begin
                                cs          <= CS_ENC_OUT;
                                cmd_to_dkey <= (mp_in == CMD_READ_IVD_ENC);
                                encout_trig_q <= 1'b1;
                                s6_cp       <= 1'b1;
                                cmd_reads   <= 4'd0;
                            end
                            CMD_ENCRYPT_MKEY: begin
                                cs      <= CS_EMK;
                                inp_cnt <= 4'd0;
                                s6_cp   <= 1'b1;
                            end
                            default: ;   // A8: undefined commands ignored
                        endcase
                    end
                end else if (sel == SEL_MODE) begin
                    mode_q         <= mp_in;
                    soft_reset     <= 1'b1;
                    soft_keep_mode <= 1'b1;
                end else if (sel == SEL_INPUT) begin
                    if (inp_push_mp && !(cs == CS_EMK && inp_full_mp)) begin
                        if (cs == CS_COLLECT) begin
                            cmd_buf <= {cmd_buf[55:0], mp_in};
                            // Clear key loads are parity-checked on entry;
                            // encrypted loads are checked after decryption
                            // (datasheet p. 2-469/2-470, spec A12).
                            if (cmd_is_key && !cmd_enc_load) begin
                                s3_par  <= f_bad_parity(mp_in);
                                s4_lpar <= s4_lpar | f_bad_parity(mp_in);
                            end
                            if (cmd_cnt == 3'd7) begin
                                if (cmd_enc_load) begin
                                    cs         <= CS_DEC;
                                    dec_trig_q <= 1'b1;
                                end else begin
                                    if (cmd_is_iv) begin
                                        if (cmd_to_dkey) ivd_q <= {cmd_buf[55:0], mp_in};
                                        else             ive_q <= {cmd_buf[55:0], mp_in};
                                    end else if (cmd_is_mkey) begin
                                        k_key_q <= {cmd_buf[55:0], mp_in};
                                    end else begin
                                        if (cmd_to_dkey) d_key_q <= {cmd_buf[55:0], mp_in};
                                        else             e_key_q <= {cmd_buf[55:0], mp_in};
                                    end
                                    s6_cp <= 1'b0;
                                    cs    <= CS_IDLE;
                                end
                            end else begin
                                cmd_cnt <= cmd_cnt + 3'd1;
                            end
                        end else begin
                            // Session data byte (or EMK byte).
                            if (!inp_full_mp) begin
                                inp_bytes[inp_cnt[2:0]] <= mp_in;
                                inp_cnt <= inp_cnt + 4'd1;
                            end
                        end
                    end
                end
            end

            // ---- slave-port input writes (dual-port sessions) ----
            if (inp_push_sp) begin
                inp_bytes[inp_cnt[2:0]] <= sp_in;
                inp_cnt <= inp_cnt + 4'd1;
            end

            // ---- mode reset applied one cycle after the write ----
            if (soft_reset) begin
                cs            <= CS_IDLE;
                emk_active_q  <= 1'b0;
                dec_pend_q    <= 1'b0;
                encout_pend_q <= 1'b0;
                s7_start      <= 1'b0;
                s6_cp        <= 1'b0;
                s4_lpar      <= 1'b0;
                s3_par       <= 1'b0;
                if (!soft_keep_mode) mode_q <= MODE_RESET;
                inp_cnt      <= 4'd0;
                out_cnt      <= 4'd0;
                inp_holdoff  <= 4'd0;
                deliver_pend <= 1'b0;
                deliver_cnt  <= 3'd0;
                blackout     <= 1'b1;
                blackout_cnt <= 3'd4;   // total 5 clocks with this edge
                cmd_cnt      <= 3'd0;
                cmd_reads    <= 4'd0;
                iv_delay     <= 3'd0;
            end

            // ---- auxiliary (ASTB) key-byte collection ----
            if (astb_rise && cs == CS_COLLECT && cmd_via_aux && !blackout) begin
                cmd_buf <= {cmd_buf[55:0], aux_in};
                // Clear key loads are parity-checked on entry; encrypted
                // loads are checked after decryption (spec A12).
                if (cmd_is_key && !cmd_enc_load) begin
                    s3_par  <= f_bad_parity(aux_in);
                    s4_lpar <= s4_lpar | f_bad_parity(aux_in);
                end
                if (cmd_cnt == 3'd7) begin
                    if (cmd_enc_load) begin
                        cs         <= CS_DEC;
                        dec_trig_q <= 1'b1;
                    end else begin
                        if (cmd_is_mkey) k_key_q <= {cmd_buf[55:0], aux_in};
                        else if (cmd_to_dkey) d_key_q <= {cmd_buf[55:0], aux_in};
                        else                  e_key_q <= {cmd_buf[55:0], aux_in};
                        s6_cp <= 1'b0;
                        cs    <= CS_IDLE;
                    end
                end else begin
                    cmd_cnt <= cmd_cnt + 3'd1;
                end
            end

            // ---- direct-control-mode pin commands ----
            if (ck) begin
                if (kd_rise && !cmd_active) begin
                    cs           <= CS_COLLECT;
                    cmd_via_aux  <= 1'b0;
                    cmd_cnt      <= 3'd0;
                    cmd_is_key   <= 1'b1;
                    cmd_is_iv    <= 1'b0;
                    cmd_is_mkey  <= 1'b0;
                    cmd_enc_load <= 1'b0;
                    cmd_to_dkey  <= ~aux_in[6];   // E/D low = D key
                    s6_cp        <= 1'b1;
                    s4_lpar      <= 1'b0;
                end
                if (kd_fall && cs == CS_COLLECT) begin
                    cs    <= CS_IDLE;
                    s6_cp <= 1'b0;
                end
                if (ss_rise && !cmd_active) begin
                    s7_start    <= 1'b1;
                    mode_q[4]   <= aux_in[6];
                    inp_cnt     <= 4'd0;
                    inp_holdoff <= 4'd0;
                    case (mode_cipher)
                        CIPHER_CBC: chain_q <= aux_in[6] ? ive_q : ivd_q;
                        CIPHER_CFB: chain_q <= aux_in[6] ? ive_q : ivd_q;
                        default: ;
                    endcase
                end
                if (ss_fall) s7_start <= 1'b0;
            end
        end
    end

`ifdef FORMAL
    // Defined power-on values so the free-initialization of an unconstrained
    // formal state space cannot violate the bounds before the first reset
    // cycle (yosys evaluates immediate assertions post-NBA and starts
    // uninitialized registers at free values).
    initial begin
        inp_cnt  = 4'd0;
        out_cnt  = 4'd0;
        cs       = CS_IDLE;
        s7_start = 1'b0;
        f_out_pop_q = 1'b0;
        f_out_empty_q = 1'b1;
        f_sess_q = 1'b0;
        f_s7_q = 1'b0;
        f_cmdact_q = 1'b0;
        f_busy_q = 1'b0;
        f_emk_q = 1'b0;
        f_cs_emk_q = 1'b0;
        f_inp8_q = 1'b0;
    end

    // Registered pre-edge copies: immediate assertions in always_ff are
    // evaluated against the post-NBA state by yosys, so the checked
    // conditions are sampled one cycle earlier.
    logic f_out_pop_q, f_out_empty_q;
    logic f_sess_q, f_s7_q, f_cmdact_q, f_busy_q, f_emk_q, f_cs_emk_q,
          f_inp8_q;
    always_ff @(posedge clk) begin
        f_out_pop_q   <= out_pop;
        f_out_empty_q <= out_empty;
        f_sess_q      <= sess_trig;
        f_s7_q        <= s7_start;
        f_cmdact_q    <= cmd_active;
        f_busy_q      <= alg_busy;
        f_emk_q       <= emk_trig;
        f_cs_emk_q    <= (cs == CS_EMK);
        f_inp8_q      <= (inp_cnt == 4'd8);
    end

    // P7: FIFO bounds; pops only from a non-empty register.
    always_ff @(posedge clk) if (!rst_i) begin
        assert (inp_cnt <= 4'd8);
        assert (out_cnt <= 4'd8);
        if (f_out_pop_q) assert (!f_out_empty_q);
    end
    // P8: session starts require an active session and a full block.
    always_ff @(posedge clk) if (!rst_i) begin
        if (f_sess_q) assert (f_s7_q && !f_cmdact_q && !f_busy_q);
        if (f_emk_q)  assert (f_cs_emk_q && f_inp8_q);
    end
    // Covers: command completion, each cipher mode, parity error, HW reset.
    logic f_pump, f_ecb, f_cbc, f_cfb, f_par, f_hw, f_keyload, f_auxkey;
    always_ff @(posedge clk) begin
        if (rst_i) begin
            f_pump <= 1'b0; f_ecb <= 1'b0; f_cbc  <= 1'b0;
            f_cfb  <= 1'b0; f_par <= 1'b0; f_hw   <= 1'b0;
            f_keyload <= 1'b0; f_auxkey <= 1'b0;
        end else begin
            if (cs == CS_PUMP && cmd_reads == 4'd7) f_pump <= 1'b1;
            if (alg_done && !cmd_active && !mode_cfb && !mode_cbc) f_ecb <= 1'b1;
            if (alg_done && !cmd_active && mode_cbc)  f_cbc <= 1'b1;
            if (alg_done && !cmd_active && mode_cfb)  f_cfb <= 1'b1;
            if (s4_lpar)            f_par <= 1'b1;
            if (hw_reset)           f_hw  <= 1'b1;
            if (cs == CS_DEC)       f_keyload <= 1'b1;
            if (s2_aflg)            f_auxkey <= 1'b1;
            cover (f_pump);
            cover (f_ecb);
            cover (f_cbc);
            cover (f_cfb);
            cover (f_par);
            cover (f_hw);
            cover (f_keyload);
            cover (f_auxkey);
        end
    end
`endif

endmodule

`default_nettype wire
