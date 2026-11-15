// des_core.sv — single-block DES engine (FIPS PUB 46, 1977).
//
// One round per clock; a block occupies 18 clocks (initial-permutation
// load, 16 rounds, final-permutation store) to match the Am9518 algorithm
// window documented in the datasheet timing figures (p. 2-477).
//
// The engine always computes the DES encryption transform; decryption is
// produced by consuming the round-key sequence in reverse order (standard
// DES property).  The caller supplies the raw 64-bit key register image;
// PC-1 runs at key-load time and drops the per-byte parity bits naturally.
//
// Bit numbering: FIPS 46 numbers bits 1..64 from the most significant bit;
// FIPS bit n corresponds to vector bit (64-n).

`default_nettype none

module des_core #(
    parameter int unsigned ALG_CYCLES = 18  // 1 + 16 rounds + 1 store
) (
    input  logic        clk,
    input  logic        rst,

    // Key image load: raw 64-bit key register (with parity bits).
    input  logic        key_load,
    input  logic [63:0] key_data,
    input  logic        key_decrypt,      // consume subkeys reversed

    // Block interface.
    input  logic        start,
    input  logic [63:0] block_in,
    output logic [63:0] result,
    output logic        done,             // one-cycle pulse
    output logic        busy
);

    `include "des_tables.svh"

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    logic [4:0]  cnt;               // 0 idle, 1..16 rounds, 17 store
    logic [31:0] l_reg, r_reg;
    logic [55:0] halves;            // C||D key halves for current round
    logic        dec_mode;          // consume subkeys reversed
    logic [63:0] result_q;
    logic        busy_q;

    // Key schedule image latched from the most recent key_load.
    logic [55:0] key_image_q;
    logic        key_dec_q;

    // 28-bit rotate helpers.
    function automatic logic [27:0] f_rotl28(logic [27:0] v, logic [4:0] n);
        f_rotl28 = n == 0 ? v : ((v << n) | (v >> (5'd28 - n)));
    endfunction

    function automatic logic [27:0] f_rotr28(logic [27:0] v, logic [4:0] n);
        f_rotr28 = n == 0 ? v : ((v >> n) | (v << (5'd28 - n)));
    endfunction

    // Per-round rotation amount; rnd is the 1-based round whose subkey is
    // about to be used.
    function automatic logic [4:0] f_ls(logic [4:0] rnd);
        case (rnd)
            5'd1, 5'd2, 5'd9, 5'd16: f_ls = 5'd1;
            default:                 f_ls = 5'd2;
        endcase
    endfunction

    // PC-1 intentionally reads only the 56 key bits; the eight per-byte
    // parity bits are structurally unused (spec A14).
    /* verilator lint_off UNUSEDSIGNAL */
    wire logic unused_parity_bits = ^{key_data[63:56], ALG_CYCLES != 18};
    /* verilator lint_on UNUSEDSIGNAL */

    wire logic [47:0] subkey   = f_pc2(halves);
    wire logic [47:0] expanded = f_expand(r_reg);
    wire logic [31:0] f_out    = f_pbox(f_sboxes(expanded ^ subkey));

    // Key image entering round 1: PC-1 of the (possibly same-cycle) key,
    // with the first left rotation already applied for encryption (K_r =
    // PC2(C_r D_r)) and the raw image for decryption (K_(17-r); C16 = C0).
    logic        img_dec;
    logic [55:0] img_next;
    always_comb begin
        img_dec  = key_load ? key_decrypt : key_dec_q;
        img_next = key_load ? f_pc1(key_data) : key_image_q;
        if (!img_dec) begin
            img_next = {f_rotl28(img_next[55:28], f_ls(5'd1)),
                        f_rotl28(img_next[27:0],  f_ls(5'd1))};
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            cnt         <= 5'd0;
            busy_q      <= 1'b0;
            done        <= 1'b0;
            key_image_q <= 56'd0;
            key_dec_q   <= 1'b0;
            result_q    <= 64'd0;
            l_reg       <= 32'd0;
            r_reg       <= 32'd0;
            halves      <= 56'd0;
            dec_mode    <= 1'b0;
        end else begin
            done <= 1'b0;

            if (key_load) begin
                key_image_q <= f_pc1(key_data);
                key_dec_q   <= key_decrypt;
            end

            if (start && !busy_q) begin
                cnt      <= 5'd1;
                busy_q   <= 1'b1;
                // A key_load asserted in the same cycle takes precedence.
                dec_mode <= img_dec;
                halves   <= img_next;
                {l_reg, r_reg} <= f_ip(block_in);
            end else if (busy_q) begin
                if (cnt <= 5'd16) begin
                    // halves holds the halves for this round's subkey.
                    if (!dec_mode) begin
                        halves <= {f_rotl28(halves[55:28], f_ls(cnt+5'd1)),
                                   f_rotl28(halves[27:0],  f_ls(cnt+5'd1))};
                    end else begin
                        halves <= {f_rotr28(halves[55:28], f_ls(17-cnt)),
                                   f_rotr28(halves[27:0],  f_ls(17-cnt))};
                    end
                    {l_reg, r_reg} <= {r_reg, l_reg ^ f_out};
                    cnt <= cnt + 5'd1;
                end else begin
                    // cnt == 17: final permutation and store.
                    result_q <= f_fp({r_reg, l_reg});
                    done     <= 1'b1;
                    busy_q   <= 1'b0;
                    cnt      <= 5'd0;
                end
            end
        end
    end

    assign result = result_q;
    assign busy   = busy_q;

`ifdef FORMAL
    // Defined power-on values for the formal-checked registers and their
    // registered pre-edge copies (yosys starts uninitialized registers at
    // free values).
    logic f_start_q, f_busy_pre_q, f_cnt17_q;
    initial begin
        cnt    = 5'd0;
        busy_q = 1'b0;
        done   = 1'b0;
        f_start_q = 1'b0;
        f_busy_pre_q = 1'b0;
        f_cnt17_q = 1'b0;
    end

    // Registered pre-edge copies (yosys evaluates immediate assertions
    // post-NBA).  done and f_cnt17_q are assigned from the same pre-edge
    // cnt value, so comparing them one timestep later is sound.
    always_ff @(posedge clk) begin
        f_start_q    <= start;
        f_busy_pre_q <= busy_q;
        f_cnt17_q    <= (cnt == 5'd17);
    end
    always_ff @(posedge clk) if (!rst) begin
        if (f_start_q) assert (!f_busy_pre_q);
        if (done)      assert (f_cnt17_q);
    end
`endif

endmodule

`default_nettype wire
