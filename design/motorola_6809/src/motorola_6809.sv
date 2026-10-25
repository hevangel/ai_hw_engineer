// Motorola MC6809 — full documented instruction set.
// Functional-bus core: one bus transfer per clk (spec/spec.md section 3.2).
// Semantics sourced from the Motorola MC6809 data sheet / programming
// manual: CC = E F H I N Z V C; subtract-family C is the borrow; MUL C =
// product bit 7; ABX adds B unsigned; stack frames are CC, A, B, DP, X,
// Y, U/S, PC bottom-up (pushes PC first, CC last); FIRQ stacks PC+CC only
// (E=0) and sets both F and I; NMI is edge-latched and disarmed until the
// first LDS after reset. Third-party gate: reyco2000 6809_functional_test
// and 6809_interrupt_test (self-checking binaries).
`timescale 1ns/1ps

module motorola_6809 (
    input  logic        clk,
    input  logic        rst_n,
    output logic [15:0] bus_addr,
    input  logic [7:0]  bus_data_i,
    output logic [7:0]  bus_data_o,
    output logic        bus_we,
    output logic        vma_o,
    input  logic        irq_n,
    input  logic        firq_n,
    input  logic        nmi_n,
    output logic        halted_o,
    output logic        sync_o,
    output logic [15:0] pc_o,
    output logic [15:0] x_o, y_o, u_o, s_o,
    output logic [7:0]  a_o, b_o, dp_o, cc_o
);

    localparam int FC = 0, FV = 1, FZ = 2, FN = 3, FI = 4, FH = 5,
                   FF = 6, FE = 7;

    // MC6809 vector map (M6809 Programming Manual / MAME m6809 agree):
    // FFF2 SWI3, FFF4 SWI2, FFF6 FIRQ, FFF8 IRQ, FFFA SWI, FFFC NMI,
    // FFFE RESET; FFF0/FFF1 reserved
    localparam logic [15:0] VEC_SWI3 = 16'hFFF2,
                            VEC_SWI2 = 16'hFFF4,
                            VEC_FIRQ = 16'hFFF6,
                            VEC_IRQ  = 16'hFFF8,
                            VEC_SWI  = 16'hFFFA,
                            VEC_NMI  = 16'hFFFC,
                            VEC_RST  = 16'hFFFE;

    typedef enum logic [5:0] {
        S_RST_L, S_RST_H, S_FETCH, S_PRE,
        S_IMM, S_DIR, S_EXT_L, S_EXT_H,
        S_PB, S_PBF, S_PBF_H, S_PBF_L, S_EAC5, S_INDF, S_INDF2, S_EA_OK,
        S_REL, S_LREL_H, S_LREL_L,
        S_RD, S_RD_H, S_RD_L, S_WR, S_WR_H, S_WR_L,
        S_RMW_R, S_RMW_E, S_RMW_W,
        S_PUSH, S_PULL, S_PUSHQ, S_PULLQ, S_RTIQ,
        S_VEC_L, S_VEC_H, S_WAIT, S_SYNCW,
        S_JSR1, S_JSR2,
        S_RTS_H, S_RTS_L
    } state_e;

    typedef enum logic [5:0] {
        S2_IMP, S2_IMM8, S2_IMM16, S2_DIR, S2_EXT, S2_IDX, S2_REL, S2_LREL
    } mode_e;

    typedef enum logic [7:0] {
        O_SUB, O_CMP, O_SBC, O_AND, O_BIT, O_LDA, O_STA,
        O_EOR, O_ADC, O_ORA, O_ADD,
        O_LDD, O_LDX, O_LDY, O_LDU, O_LDS,
        O_STD, O_STX, O_STY, O_STU, O_STS,
        O_ADDD, O_SUBD, O_CMPD, O_CMPX, O_CMPY, O_CMPU, O_CMPS,
        O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
        O_DEC, O_INC, O_TST, O_CLR,
        O_NOP, O_SEX, O_MUL, O_ABX, O_DAA,
        O_TFR, O_EXG, O_ANDCC, O_ORCC,
        O_LEAX, O_LEAY, O_LEAS, O_LEAU,
        O_PSHS, O_PULS, O_PSHU, O_PULU,
        O_BRAFAM, O_LBRAFAM,
        O_JMP, O_JSR, O_BSR, O_RTS, O_RTI,
        O_CWAI, O_SYNC, O_SWI, O_SWI2, O_SWI3
    } op_e;

    state_e state;
    mode_e  mode;
    op_e    op;
    logic   acc;             // 1 = ACCA, 0 = ACCB
    logic [1:0] pre;         // prefix: 0 none, 1 = $10, 2 = $11
    logic [15:0] pc, x, y, u, s, ea_q, vec_q, ret_q;
    logic [7:0]  a, b, dp, cc, opcode, data_q, pb_q, rmw_q;
    logic [4:0]  cond;       // branch condition index
    logic        pb_ind;     // indexed: indirect pointer fetch requested
    logic        pb_pcr;     // indexed: PCR-relative offsets
    logic [1:0]  pbr_q;      // indexed register (0=X 1=Y 2=U 3=S)
    logic [7:0]  pbm_q;      // push/pull remaining register mask
    logic        pq_hi;      // current queue byte is a 16-bit high byte
    logic        pq_us;      // the bit-6 slot acts on S (1) or U (0)
    logic        pq_int;     // queue is an interrupt/CWAI frame
    logic        pq_push;    // queue direction: 1 = push, 0 = pull
    logic        pq_br;      // after the queue: pc <= ea_q (BSR/LBSR/JSR)
    logic        pq_lea;     // after the queue: LEA-style (unused, spare)
    logic        frame_e;    // interrupt frame entire (1) / FIRQ (0)
    logic        cwai_flag;  // wait entered from CWAI
    logic [3:0]  cnt;
    logic        nmi_prev, nmi_pend, nmi_arm;

    assign pc_o = pc;
    assign x_o = x; assign y_o = y; assign u_o = u; assign s_o = s;
    assign a_o = a; assign b_o = b; assign dp_o = dp; assign cc_o = cc;

    wire irq_req  = !irq_n && !cc[FI];
    wire firq_req = !firq_n && !cc[FF];
    wire nmi_live = nmi_pend && nmi_arm;
    wire any_int  = nmi_live || firq_req || irq_req;
    wire int_take = (state == S_FETCH) && any_int;
    wire sync_wake = (state == S_SYNCW) && any_int;
    wire cwai_wake = (state == S_WAIT) && any_int;

    assign sync_o   = (state == S_FETCH) && !int_take;
    assign halted_o = (state == S_WAIT) || (state == S_SYNCW);

    function automatic logic [15:0] f_r16(input logic [1:0] r);
        case (r)
            2'h0:    f_r16 = x;
            2'h1:    f_r16 = y;
            2'h2:    f_r16 = u;
            default: f_r16 = s;
        endcase
    endfunction

    task automatic w_r16(input logic [1:0] r, input logic [15:0] v);
        case (r)
            2'h0: x = v;
            2'h1: y = v;
            2'h2: u = v;
            default: s = v;
        endcase
    endtask

    // push order: PC,U,Y,X,DP,B,A,CC (highest set bit first)
    function automatic logic [2:0] f_hibit(input logic [7:0] m);
        casez (m)
            8'b1???????: f_hibit = 3'd7;
            8'b01??????: f_hibit = 3'd6;
            8'b001?????: f_hibit = 3'd5;
            8'b0001????: f_hibit = 3'd4;
            8'b00001???: f_hibit = 3'd3;
            8'b000001??: f_hibit = 3'd2;
            8'b0000001?: f_hibit = 3'd1;
            default:     f_hibit = 3'd0;
        endcase
    endfunction

    // pull order: CC,A,B,DP,X,Y,U,PC (lowest set bit first)
    function automatic logic [2:0] f_lobit(input logic [7:0] m);
        casez (m)
            8'b???????1: f_lobit = 3'd0;
            8'b??????10: f_lobit = 3'd1;
            8'b?????100: f_lobit = 3'd2;
            8'b????1000: f_lobit = 3'd3;
            8'b???10000: f_lobit = 3'd4;
            8'b??100000: f_lobit = 3'd5;
            8'b?1000000: f_lobit = 3'd6;
            default:     f_lobit = 3'd7;
        endcase
    endfunction

    function automatic logic [8:0] f_add8(input logic [7:0] xv, yv,
                                          input logic ci);
        f_add8 = {1'b0, xv} + {1'b0, yv} + ci;
    endfunction

    // Overflow for addition: the two SIGN CHANGES between operands and
    // result — (x^r)&(y^r). (x^y)&(x^r) is the SUBTRACT formula and
    // wrongly flags mixed-sign adds like $00+$80.
    function automatic logic f_vadd(input logic [7:0] xv, yv, r);
        f_vadd = (xv[7] ^ r[7]) & (yv[7] ^ r[7]);
    endfunction

    function automatic logic [8:0] f_sub8(input logic [7:0] xv, yv,
                                          input logic borrow_in);
        f_sub8 = {1'b0, xv} - {1'b0, yv} - borrow_in;
    endfunction

    function automatic logic f_vsub(input logic [7:0] xv, yv, r);
        f_vsub = (xv[7] ^ yv[7]) & (xv[7] ^ r[7]);
    endfunction

    function automatic logic [16:0] f_add16(input logic [15:0] xv, yv,
                                            input logic ci);
        f_add16 = {1'b0, xv} + {1'b0, yv} + ci;
    endfunction

    function automatic logic f_vadd16(input logic [15:0] xv, yv, r);
        f_vadd16 = (xv[15] ^ r[15]) & (yv[15] ^ r[15]);
    endfunction

    function automatic logic [16:0] f_sub16(input logic [15:0] xv, yv,
                                            input logic borrow_in);
        f_sub16 = {1'b0, xv} - {1'b0, yv} - borrow_in;
    endfunction

    function automatic logic f_vsub16(input logic [15:0] xv, yv, r);
        f_vsub16 = (xv[15] ^ yv[15]) & (xv[15] ^ r[15]);
    endfunction

    function automatic logic f_hcarry(input logic [7:0] xv, yv,
                                      input logic ci);
        f_hcarry = ({1'b0, xv[3:0]} + {1'b0, yv[3:0]} + ci) > 5'd15;
    endfunction

    function automatic logic [8:0] f_daa(input logic [7:0] val,
                                         input logic hh, c_in);
        logic [3:0] lo, hi;
        logic       nd, md;
        logic [7:0] addend;
        lo = val[3:0];
        hi = val[7:4];
        nd = (lo > 4'h9) || hh;
        md = c_in || (hi > 4'h9) || (hi == 4'h9 && (lo > 4'h9));
        addend = {1'b0, md, md, 2'b00, nd, nd, 1'b0};
        f_daa = {md, val + addend};
    endfunction

    function automatic logic f_branch(input logic [4:0] ci_,
                                      input logic [7:0] c);
        // cond index = {1'b1, opcode[3:0]}: 20 BRA, 21 BRN, 22 BHI,
        // 23 BLS, 24 BCC, 25 BCS, 26 BNE, 27 BEQ, 28 BVC, 29 BVS,
        // 2A BPL, 2B BMI, 2C BGE, 2D BLT, 2E BGT, 2F BLE
        case (ci_)
            5'h10:   f_branch = 1'b1;
            5'h11:   f_branch = 1'b0;
            5'h12:   f_branch = !c[FC] && !c[FZ];
            5'h13:   f_branch =  c[FC] ||  c[FZ];
            5'h14:   f_branch = !c[FC];
            5'h15:   f_branch =  c[FC];
            5'h16:   f_branch = !c[FZ];
            5'h17:   f_branch =  c[FZ];
            5'h18:   f_branch = !c[FV];
            5'h19:   f_branch =  c[FV];
            5'h1A:   f_branch = !c[FN];
            5'h1B:   f_branch =  c[FN];
            5'h1C:   f_branch = !(c[FN] ^ c[FV]);
            5'h1D:   f_branch =  (c[FN] ^ c[FV]);
            5'h1E:   f_branch = !c[FZ] && !(c[FN] ^ c[FV]);
            default: f_branch =  c[FZ] ||  (c[FN] ^ c[FV]);
        endcase
    endfunction

    function automatic logic [9:0] f_rmw(input op_e o,
                                         input logic [7:0] val,
                                         input logic c_in);
        logic [7:0] res;
        logic       cn, vn;
        case (o)
            O_NEG: begin res = -val; cn = (val != 8'h00); vn = (val == 8'h80); end
            O_COM: begin res = ~val; cn = 1'b1; vn = 1'b0; end
            // 6809 shift V rules (differ from the 6800; suite-derived):
            // LSR and ROR clear V; ASL/ASR/ROL keep V = N after op XOR C
            O_LSR: begin res = {1'b0, val[7:1]}; cn = val[0]; vn = 1'b0; end
            O_ROR: begin res = {c_in, val[7:1]}; cn = val[0]; vn = 1'b0; end
            O_ASR: begin res = {val[7], val[7:1]}; cn = val[0]; vn = val[7] ^ val[0]; end
            O_ASL: begin res = {val[6:0], 1'b0}; cn = val[7]; vn = res[7] ^ val[7]; end
            O_ROL: begin res = {val[6:0], c_in}; cn = val[7]; vn = res[7] ^ val[7]; end
            O_DEC: begin res = val - 8'h01; cn = c_in; vn = (val == 8'h80); end
            O_INC: begin res = val + 8'h01; cn = c_in; vn = (val == 8'h7F); end
            O_TST: begin res = val; cn = c_in; vn = 1'b0; end   // C preserved
            O_CLR: begin res = 8'h00; cn = 1'b0; vn = 1'b0; end
            default: begin res = val; cn = c_in; vn = 1'b0; end
        endcase
        f_rmw = {cn, vn, res};
    endfunction

    function automatic logic f_is16(input op_e o);
        case (o)
            O_LDD, O_LDX, O_LDY, O_LDU, O_LDS,
            O_STD, O_STX, O_STY, O_STU, O_STS,
            O_ADDD, O_SUBD, O_CMPD, O_CMPX, O_CMPY, O_CMPU, O_CMPS:
                f_is16 = 1'b1;
            default: f_is16 = 1'b0;
        endcase
    endfunction

    function automatic logic f_is_rmw(input op_e o);
        case (o)
            O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
            O_DEC, O_INC, O_TST, O_CLR: f_is_rmw = 1'b1;
            default: f_is_rmw = 1'b0;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Decoder. Explicit entries set op (and mode for branches/stack/prefix
    // ops); the ALU/RMW rows leave mode = S2_IMP and the row rule derives
    // it afterwards: rows 8/C=IMM 9/D=DIR A/E=IDX B/F=EXT for 8x-Fx, and
    // 0=DIR 6=IDX 7=EXT for the RMW/JMP rows.
    // ------------------------------------------------------------------
    function automatic void f_decode(input logic [7:0] d,
                                     input logic [1:0] pfx,
                                     output op_e o_op,
                                     output mode_e o_mode,
                                     output logic o_acc,
                                     output logic [4:0] o_cond);
        o_op = O_NOP; o_mode = S2_IMP; o_acc = 1'b0; o_cond = 5'h10;
        if (pfx == 2'b00) begin
            case (d)
                8'h12: o_op = O_NOP;
                8'h13: o_op = O_SYNC;
                8'h3D: o_op = O_MUL;
                8'h16: begin o_op = O_LBRAFAM; o_mode = S2_LREL; o_cond = 5'h10; end
                8'h17: begin o_op = O_BSR; o_mode = S2_LREL; end
                8'h19: o_op = O_DAA;
                8'h1A: begin o_op = O_ORCC; o_mode = S2_IMM8; end
                8'h1C: begin o_op = O_ANDCC; o_mode = S2_IMM8; end
                8'h1D: o_op = O_SEX;
                8'h1E: begin o_op = O_EXG; o_mode = S2_IMM8; end
                8'h1F: begin o_op = O_TFR; o_mode = S2_IMM8; end
                8'h30: begin o_op = O_LEAX; o_mode = S2_IDX; end
                8'h31: begin o_op = O_LEAY; o_mode = S2_IDX; end
                8'h32: begin o_op = O_LEAS; o_mode = S2_IDX; end
                8'h33: begin o_op = O_LEAU; o_mode = S2_IDX; end
                8'h34: begin o_op = O_PSHS; o_mode = S2_IMM8; end
                8'h35: begin o_op = O_PULS; o_mode = S2_IMM8; end
                8'h36: begin o_op = O_PSHU; o_mode = S2_IMM8; end
                8'h37: begin o_op = O_PULU; o_mode = S2_IMM8; end
                8'h3A: o_op = O_ABX;
                8'h39: o_op = O_RTS;
                8'h3B: o_op = O_RTI;
                8'h3C: begin o_op = O_CWAI; o_mode = S2_IMM8; end
                8'h3F: o_op = O_SWI;
                // accumulator RMW: 0x4x = ACCA, 0x5x = ACCB (bit 4
                // discriminates; inherent mode)
                8'h40, 8'h50: begin o_op = O_NEG; o_acc = ~d[4]; end
                8'h43, 8'h53: begin o_op = O_COM; o_acc = ~d[4]; end
                8'h44, 8'h54: begin o_op = O_LSR; o_acc = ~d[4]; end
                8'h46, 8'h56: begin o_op = O_ROR; o_acc = ~d[4]; end
                8'h47, 8'h57: begin o_op = O_ASR; o_acc = ~d[4]; end
                8'h48, 8'h58: begin o_op = O_ASL; o_acc = ~d[4]; end
                8'h49, 8'h59: begin o_op = O_ROL; o_acc = ~d[4]; end
                8'h4A, 8'h5A: begin o_op = O_DEC; o_acc = ~d[4]; end
                8'h4C, 8'h5C: begin o_op = O_INC; o_acc = ~d[4]; end
                8'h4D, 8'h5D: begin o_op = O_TST; o_acc = ~d[4]; end
                8'h4F, 8'h5F: begin o_op = O_CLR; o_acc = ~d[4]; end
                8'h8D: begin o_op = O_BSR; o_mode = S2_REL; end
                8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27,
                8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D, 8'h2E, 8'h2F:
                    begin o_op = O_BRAFAM; o_mode = S2_REL;
                          o_cond = {1'b1, d[3:0]}; end
                default: o_op = O_NOP;
            endcase
            if (o_op == O_NOP && d != 8'h12) begin
                case (d)
                    8'h00, 8'h60, 8'h70: o_op = O_NEG;
                    8'h03, 8'h63, 8'h73: o_op = O_COM;
                    8'h04, 8'h64, 8'h74: o_op = O_LSR;
                    8'h06, 8'h66, 8'h76: o_op = O_ROR;
                    8'h07, 8'h67, 8'h77: o_op = O_ASR;
                    8'h08, 8'h68, 8'h78: o_op = O_ASL;
                    8'h09, 8'h69, 8'h79: o_op = O_ROL;
                    8'h0A, 8'h6A, 8'h7A: o_op = O_DEC;
                    8'h0C, 8'h6C, 8'h7C: o_op = O_INC;
                    8'h0D, 8'h6D, 8'h7D: o_op = O_TST;
                    8'h0F, 8'h6F, 8'h7F: o_op = O_CLR;
                    8'h0E, 8'h6E, 8'h7E: o_op = O_JMP;
                    8'h9D, 8'hAD, 8'hBD: o_op = O_JSR;
                    8'h80, 8'h90, 8'hB0, 8'hA0: begin o_op = O_SUB; o_acc = ~d[6]; end
                    8'h81, 8'h91, 8'hB1, 8'hA1: begin o_op = O_CMP; o_acc = ~d[6]; end
                    8'h82, 8'h92, 8'hB2, 8'hA2: begin o_op = O_SBC; o_acc = ~d[6]; end
                    8'h84, 8'h94, 8'hB4, 8'hA4: begin o_op = O_AND; o_acc = ~d[6]; end
                    8'h85, 8'h95, 8'hB5, 8'hA5: begin o_op = O_BIT; o_acc = ~d[6]; end
                    8'h86, 8'h96, 8'hB6, 8'hA6: begin o_op = O_LDA; o_acc = ~d[6]; end
                    8'h87, 8'h97, 8'hB7, 8'hA7: begin o_op = O_STA; o_acc = ~d[6]; end
                    8'h88, 8'h98, 8'hB8, 8'hA8: begin o_op = O_EOR; o_acc = ~d[6]; end
                    8'h89, 8'h99, 8'hB9, 8'hA9: begin o_op = O_ADC; o_acc = ~d[6]; end
                    8'h8A, 8'h9A, 8'hBA, 8'hAA: begin o_op = O_ORA; o_acc = ~d[6]; end
                    8'h8B, 8'h9B, 8'hBB, 8'hAB: begin o_op = O_ADD; o_acc = ~d[6]; end
                    8'hC0, 8'hD0, 8'hF0, 8'hE0: begin o_op = O_SUB; o_acc = ~d[6]; end
                    8'hC1, 8'hD1, 8'hF1, 8'hE1: begin o_op = O_CMP; o_acc = ~d[6]; end
                    8'hC2, 8'hD2, 8'hF2, 8'hE2: begin o_op = O_SBC; o_acc = ~d[6]; end
                    8'hC4, 8'hD4, 8'hF4, 8'hE4: begin o_op = O_AND; o_acc = ~d[6]; end
                    8'hC5, 8'hD5, 8'hF5, 8'hE5: begin o_op = O_BIT; o_acc = ~d[6]; end
                    8'hC6, 8'hD6, 8'hF6, 8'hE6: begin o_op = O_LDA; o_acc = ~d[6]; end
                    8'hC7, 8'hD7, 8'hF7, 8'hE7: begin o_op = O_STA; o_acc = ~d[6]; end
                    8'hC8, 8'hD8, 8'hF8, 8'hE8: begin o_op = O_EOR; o_acc = ~d[6]; end
                    8'hC9, 8'hD9, 8'hF9, 8'hE9: begin o_op = O_ADC; o_acc = ~d[6]; end
                    8'hCA, 8'hDA, 8'hFA, 8'hEA: begin o_op = O_ORA; o_acc = ~d[6]; end
                    8'hCB, 8'hDB, 8'hFB, 8'hEB: begin o_op = O_ADD; o_acc = ~d[6]; end
                    8'h83, 8'h93, 8'hB3, 8'hA3: o_op = O_SUBD;
                    8'h8C, 8'h9C, 8'hBC, 8'hAC: o_op = O_CMPX;
                    8'h8E, 8'h9E, 8'hBE, 8'hAE: o_op = O_LDX;
                    8'hC3, 8'hD3, 8'hF3, 8'hE3: o_op = O_ADDD;
                    8'hCC, 8'hDC, 8'hFC, 8'hEC: o_op = O_LDD;
                    8'hCE, 8'hDE, 8'hFE, 8'hEE: o_op = O_LDU;
                    8'h9F, 8'hBF, 8'hAF: o_op = O_STX;
                    8'hDD, 8'hFD, 8'hED: o_op = O_STD;
                    8'hDF, 8'hFF, 8'hEF: o_op = O_STU;
                    default: o_op = O_NOP;
                endcase
                if (o_op != O_NOP) begin
                    if (d >= 8'h80) begin
                        case (d[6:4])
                            3'h0, 3'h4: o_mode = f_is16(o_op) ? S2_IMM16 : S2_IMM8;
                            3'h1, 3'h5: o_mode = S2_DIR;
                            3'h2, 3'h6: o_mode = S2_IDX;
                            default:    o_mode = S2_EXT;
                        endcase
                    end else begin
                        case (d[6:4])
                            3'h0:    o_mode = S2_DIR;
                            3'h6:    o_mode = S2_IDX;
                            3'h7:    o_mode = S2_EXT;
                            default: o_mode = S2_IMP;
                        endcase
                    end
                end
            end
            // JMP/JSR set op in the first case; derive their mode here
            if ((o_op == O_JMP || o_op == O_JSR) && o_mode == S2_IMP) begin
                if (d >= 8'h80) begin
                    case (d[6:4])
                        3'h1, 3'h5: o_mode = S2_DIR;
                        3'h2, 3'h6: o_mode = S2_IDX;
                        3'h3, 3'h7: o_mode = S2_EXT;
                        default:    o_mode = S2_DIR;
                    endcase
                end else begin
                    case (d[6:4])
                        3'h0:    o_mode = S2_DIR;
                        3'h6:    o_mode = S2_IDX;
                        3'h7:    o_mode = S2_EXT;
                        default: o_mode = S2_DIR;
                    endcase
                end
            end
        end else if (pfx == 2'b01) begin
            // page 2 ($10)
            case (d)
                8'h3F: o_op = O_SWI2;
                8'h16: begin o_op = O_LBRAFAM; o_mode = S2_LREL; o_cond = 5'h10; end
                8'h17: begin o_op = O_BSR; o_mode = S2_LREL; end
                8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26, 8'h27,
                8'h28, 8'h29, 8'h2A, 8'h2B, 8'h2C, 8'h2D, 8'h2E, 8'h2F:
                    begin o_op = O_LBRAFAM; o_mode = S2_LREL;
                          o_cond = {1'b1, d[3:0]}; end
                8'h83, 8'h93, 8'hB3, 8'hA3: o_op = O_CMPD;
                8'h8C, 8'h9C, 8'hBC, 8'hAC: o_op = O_CMPY;
                8'h8E, 8'h9E, 8'hBE, 8'hAE: o_op = O_LDY;
                8'h9F, 8'hAF, 8'hBF: o_op = O_STY;
                8'hCE, 8'hDE, 8'hFE, 8'hEE: o_op = O_LDS;
                8'hDF, 8'hEF, 8'hFF: o_op = O_STS;
                default: o_op = O_NOP;
            endcase
            if (o_op != O_NOP && d >= 8'h80) begin
                case (d[6:4])
                    3'h0, 3'h4: o_mode = S2_IMM16;
                    3'h1, 3'h5: o_mode = S2_DIR;
                    3'h2, 3'h6: o_mode = S2_IDX;
                    default:    o_mode = S2_EXT;
                endcase
            end
        end else begin
            // page 3 ($11)
            case (d)
                8'h3F: o_op = O_SWI3;
                8'h83, 8'h93, 8'hB3, 8'hA3: o_op = O_CMPU;
                8'h8C, 8'h9C, 8'hBC, 8'hAC: o_op = O_CMPS;
                default: o_op = O_NOP;
            endcase
            if (o_op != O_NOP && d >= 8'h80) begin
                case (d[6:4])
                    3'h0, 3'h4: o_mode = S2_IMM16;
                    3'h1, 3'h5: o_mode = S2_DIR;
                    3'h2, 3'h6: o_mode = S2_IDX;
                    default:    o_mode = S2_EXT;
                endcase
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Bus outputs
    // ------------------------------------------------------------------
    logic [2:0] pq_ridx;

    always_comb begin
        pq_ridx = pq_push ? f_hibit(pbm_q) : f_lobit(pbm_q);
    end

    // is the current queue register 16-bit?
    function automatic logic pq_is16(input logic [2:0] r);
        pq_is16 = (r == 3'd7) || (r == 3'd6) || (r == 3'd5) || (r == 3'd4);
    endfunction

    // push byte for the current queue position
    always_comb begin
        bus_data_o = 8'h00;
        stored16_q = stored16();
        case (state)
            S_PUSH: bus_data_o = acc ? a : b;
            S_WR:   bus_data_o = acc ? a : b;
            S_WR_H: bus_data_o = stored16_q[15:8];
            S_WR_L: bus_data_o = stored16_q[7:0];
            S_JSR1: bus_data_o = ret_q[7:0];
            S_JSR2: bus_data_o = ret_q[15:8];
            S_PUSHQ: begin
                case (pq_ridx)
                    3'd7: bus_data_o = pq_hi ? pc[15:8] : pc[7:0];
                    3'd6: begin
                        if (pq_us) bus_data_o = pq_hi ? s[15:8] : s[7:0];
                        else       bus_data_o = pq_hi ? u[15:8] : u[7:0];
                    end
                    3'd5: bus_data_o = pq_hi ? y[15:8] : y[7:0];
                    3'd4: bus_data_o = pq_hi ? x[15:8] : x[7:0];
                    3'd3: bus_data_o = dp;
                    3'd2: bus_data_o = b;
                    3'd1: bus_data_o = a;
                    default:
                        // CC byte: interrupt/CWAI frames force E
                        bus_data_o = pq_int ? {frame_e, cc[6:0]} : cc;
                endcase
            end
            S_RMW_W: bus_data_o = rmw_q;
            default: bus_data_o = 8'h00;
        endcase
    end

    always_comb begin
        bus_addr   = pc;
        bus_we     = 1'b0;
        vma_o      = 1'b1;
        case (state)
            S_RST_L, S_VEC_L: bus_addr = vec_q;
            S_RST_H, S_VEC_H: bus_addr = vec_q + 16'h1;
            S_FETCH, S_PRE, S_IMM, S_DIR, S_EXT_L, S_EXT_H, S_REL,
            S_PB, S_PBF, S_PBF_H, S_PBF_L, S_LREL_H, S_LREL_L:
                bus_addr = pc;
            S_RD, S_RD_H, S_INDF: bus_addr = ea_q;
            S_RD_L, S_INDF2: bus_addr = ea_q + 16'h1;
            S_WR: begin bus_addr = ea_q; bus_we = 1'b1; end
            S_WR_H: begin bus_addr = ea_q; bus_we = 1'b1; end
            S_WR_L: begin bus_addr = ea_q + 16'h1; bus_we = 1'b1; end
            S_RMW_R: bus_addr = ea_q;
            S_RMW_W: begin bus_addr = ea_q; bus_we = 1'b1; end
                // 6809 push: decrement the active pointer then store (it
                // ends AT the last byte); pull: read at the pointer then
                // increment. PSHS/PULS act on S, PSHU/PULU on U.
                S_PUSH, S_PUSHQ, S_JSR1, S_JSR2:
                    begin bus_addr = (pq_us ? u : s) - 16'h1; bus_we = 1'b1; end
            S_PULL, S_PULLQ, S_RTIQ, S_RTS_H, S_RTS_L:
                bus_addr = pq_us ? u : s;
            S_WAIT, S_SYNCW: vma_o = 1'b0;
            default: bus_addr = pc;
        endcase
    end

    // ------------------------------------------------------------------
    // Sequencer
    // ------------------------------------------------------------------
    /* verilator lint_off BLKSEQ */
    logic [8:0]  t8;
    logic [16:0] t16;
    logic [9:0]  rres;
    logic [15:0] r16v;
    logic [8:0]  daa9;
    logic        take;
    logic [15:0] prod;
    logic [15:0] stored16_q;
    logic [15:0] sext;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_RST_L; mode <= S2_IMP; op <= O_NOP; acc <= 1'b0;
            pre <= 2'b00;
            pc <= 16'h0000; x <= 16'h0000; y <= 16'h0000;
            u <= 16'h0000; s <= 16'h0000; dp <= 8'h00;
            a <= 8'h00; b <= 8'h00;
            cc <= 8'h50;             // I and F set by reset, E clear
            opcode <= 8'h00; data_q <= 8'h00; pb_q <= 8'h00;
            rmw_q <= 8'h00;
            ea_q <= 16'h0000; vec_q <= VEC_RST; ret_q <= 16'h0000;
            cond <= 5'h10;
            pb_ind <= 1'b0; pb_pcr <= 1'b0; pbr_q <= 2'h0;
            pbm_q <= 8'h00; pq_hi <= 1'b0; pq_us <= 1'b0;
            pq_int <= 1'b0; pq_br <= 1'b0; pq_lea <= 1'b0;
            frame_e <= 1'b1; cwai_flag <= 1'b0;
            cnt <= 4'd0;
            nmi_prev <= 1'b1; nmi_pend <= 1'b0; nmi_arm <= 1'b0;
        end else begin
            case (state)
                // ---------------- reset ----------------
                S_RST_L: begin
                    data_q <= bus_data_i;
                    state  <= S_RST_H;
                end
                S_RST_H: begin
                    pc <= {data_q, bus_data_i};
                    cc[FI] <= 1'b1;
                    cc[FF] <= 1'b1;
                    cc[FE] <= 1'b0;
                    nmi_pend <= 1'b0;
                    nmi_arm  <= 1'b0;
                    state <= S_FETCH;
                end

                // ---------------- fetch / decode ----------------
                S_FETCH: begin
                    if (int_take) begin
                        frame_e <= !firq_req || nmi_live;
                        pq_int  <= 1'b1;
                        pq_br   <= 1'b0;
                        pq_us   <= 1'b0;
                        pq_hi   <= 1'b0;   // pushes start at the low byte
                        cwai_flag <= 1'b0;
                        if (nmi_live) begin
                            vec_q <= VEC_NMI;
                            nmi_pend <= 1'b0;
                        end else if (firq_req) vec_q <= VEC_FIRQ;
                        else vec_q <= VEC_IRQ;
                        pbm_q <= (!firq_req || nmi_live) ? 8'hFF : 8'h81;
                        pq_push <= 1'b1;
                        state <= S_PUSHQ;
                    end else if (bus_data_i == 8'h10) begin
                        pre <= 2'b01;
                        pc <= pc + 16'h1;
                        state <= S_PRE;
                    end else if (bus_data_i == 8'h11) begin
                        pre <= 2'b10;
                        pc <= pc + 16'h1;
                        state <= S_PRE;
                    end else begin
                        pre <= 2'b00;
                        opcode <= bus_data_i;
                        pc <= pc + 16'h1;
                        f_decode(bus_data_i, 2'b00, op, mode, acc, cond);
                        if (mode == S2_IMP) exec_inherent();
                        else route_mode(mode);
                    end
                end

                S_PRE: begin
                    opcode <= bus_data_i;
                    pc <= pc + 16'h1;
                    f_decode(bus_data_i, pre, op, mode, acc, cond);
                    pre <= 2'b00;   // after the decode consumed it
                    if (mode == S2_IMP) exec_inherent();
                    else route_mode(mode);
                end

                // ---------------- immediates ----------------
                S_IMM: begin
                    data_q <= bus_data_i;
                    pc = pc + 16'h1;   // blocking: TFR/EXG y,pc overrides it
                    exec_imm8(bus_data_i);
                    // exec_imm8 sets state for stack ops; the ALU default
                    // does not, so fall through to fetch
                    if (state == S_IMM) state <= S_FETCH;
                end

                // ---------------- direct / extended ----------------
                S_DIR: begin
                    ea_q = {dp, bus_data_i};   // blocking: route_ea reads it
                    pc = pc + 16'h1;           // blocking: pc = post-instr
                    route_ea();
                end

                S_EXT_L: begin
                    data_q <= bus_data_i;
                    pc <= pc + 16'h1;
                    state <= S_EXT_H;
                end

                S_EXT_H: begin
                    ea_q = {data_q, bus_data_i};   // blocking: route_ea reads
                    pc = pc + 16'h1;               // blocking: pc = post-instr
                    route_ea();
                end

                // ---------------- indexed postbyte ----------------
                // Postbyte table (M6809 data sheet): bit7=0 -> 5-bit
                // signed offset; bit7=1 -> type in bits [4:0]:
                //   00 ,R+  01 ,R++  02 ,-R  03 ,--R  04 ,R
                //   05 B,R  06 A,R   08 n8,R  09 n16,R  0B D,R
                //   0C n8,PCR  0D n16,PCR
                //   11 [,R++] 13 [,--R] 14 [,R] 15 [B,R] 16 [A,R]
                //   18 [n8,R] 19 [n16,R] 1B [D,R] 1C [n8,PCR]
                //   1D [n16,PCR] 1F [n16]
                S_PB: begin
                    pb_q <= bus_data_i;
                    pc <= pc + 16'h1;
                    pbr_q <= bus_data_i[6:5];
                    if (!bus_data_i[7]) begin
                        // 5-bit signed offset (never indirect)
                        pb_ind <= 1'b0;
                        pb_pcr <= 1'b0;
                        ea_q <= f_r16(bus_data_i[6:5]) +
                                {{11{bus_data_i[4]}}, bus_data_i[4:0]};
                        state <= S_EA_OK;
                    end else begin
                        case (bus_data_i[4:0])
                            5'h00: begin  // ,R+
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) + 16'h1);
                                state <= S_EA_OK;
                            end
                            5'h01: begin  // ,R++
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) + 16'h2);
                                state <= S_EA_OK;
                            end
                            5'h02: begin  // ,-R
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) - 16'h1;
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) - 16'h1);
                                state <= S_EA_OK;
                            end
                            5'h03: begin  // ,--R
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) - 16'h2;
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) - 16'h2);
                                state <= S_EA_OK;
                            end
                            5'h04: begin  // ,R
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                state <= S_EA_OK;
                            end
                            5'h05: begin  // B,R (signed)
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) +
                                        {{8{b[7]}}, b};
                                state <= S_EA_OK;
                            end
                            5'h06: begin  // A,R (signed)
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) +
                                        {{8{a[7]}}, a};
                                state <= S_EA_OK;
                            end
                            5'h08, 5'h0C: begin  // n8,R / n8,PCR
                                pb_ind <= 1'b0;
                                pb_pcr <= (bus_data_i[4:0] == 5'h0C);
                                state <= S_PBF;
                            end
                            5'h09, 5'h0D: begin  // n16,R / n16,PCR
                                pb_ind <= 1'b0;
                                pb_pcr <= (bus_data_i[4:0] == 5'h0D);
                                state <= S_PBF_H;
                            end
                            5'h0B: begin  // D,R (unsigned)
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) + {a, b};
                                state <= S_EA_OK;
                            end
                            5'h11: begin  // [,R++]
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) + 16'h2);
                                state <= S_EA_OK;
                            end
                            5'h13: begin  // [,--R]
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) - 16'h2;
                                w_r16(bus_data_i[6:5],
                                      f_r16(bus_data_i[6:5]) - 16'h2);
                                state <= S_EA_OK;
                            end
                            5'h14: begin  // [,R]
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                state <= S_EA_OK;
                            end
                            5'h15: begin  // [B,R] (signed)
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) +
                                        {{8{b[7]}}, b};
                                state <= S_EA_OK;
                            end
                            5'h16: begin  // [A,R] (signed)
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) +
                                        {{8{a[7]}}, a};
                                state <= S_EA_OK;
                            end
                            5'h18, 5'h1C: begin  // [n8,R] / [n8,PCR]
                                pb_ind <= 1'b1;
                                pb_pcr <= (bus_data_i[4:0] == 5'h1C);
                                state <= S_PBF;
                            end
                            5'h19, 5'h1D, 5'h1F: begin
                                // [n16,R] / [n16,PCR] / [n16]
                                pb_ind <= 1'b1;
                                pb_pcr <= (bus_data_i[4:0] == 5'h1D);
                                state <= S_PBF_H;
                            end
                            5'h1B: begin  // [D,R]
                                pb_ind <= 1'b1; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]) + {a, b};
                                state <= S_EA_OK;
                            end
                            default: begin  // reserved -> ,R (assumption)
                                pb_ind <= 1'b0; pb_pcr <= 1'b0;
                                ea_q <= f_r16(bus_data_i[6:5]);
                                state <= S_EA_OK;
                            end
                        endcase
                    end
                end

                S_PBF: begin
                    // n8,R / n8,PCR; PCR base = address after the offset
                    pc <= pc + 16'h1;
                    if (pb_pcr) ea_q <= pc + 16'h1 +
                                        {{8{bus_data_i[7]}}, bus_data_i};
                    else ea_q <= f_r16(pbr_q) +
                                 {{8{bus_data_i[7]}}, bus_data_i};
                    state <= S_EA_OK;
                end

                S_PBF_H: begin
                    data_q <= bus_data_i;
                    pc <= pc + 16'h1;
                    state <= S_PBF_L;
                end

                S_PBF_L: begin
                    pc <= pc + 16'h1;
                    if (pb_q[4:0] == 5'h1F) begin
                        // extended indirect: the word is a pointer
                        ea_q <= {data_q, bus_data_i};
                    end else if (pb_pcr) begin
                        // PCR base = next instruction = pc + 1 (pc holds
                        // the offset-lo address at this point)
                        ea_q <= pc + 16'h1 + {data_q, bus_data_i};
                    end else begin
                        ea_q <= f_r16(pbr_q) + {data_q, bus_data_i};
                    end
                    state <= S_EA_OK;
                end

                S_EA_OK: begin
                    if (pb_ind) state <= S_INDF;
                    else route_ea();
                end

                S_INDF: begin
                    data_q <= bus_data_i;
                    state <= S_INDF2;
                end

                S_INDF2: begin
                    ea_q = {data_q, bus_data_i};   // blocking: route_ea reads
                    route_ea();
                end

                // ---------------- branches ----------------
                S_REL: begin
                    pc <= pc + 16'h1;
                    take = f_branch(cond, cc);
                    if (op == O_BSR) begin
                        // pc (pre-advance) = offset byte; base = pc + 1
                        ea_q  = pc + 16'h1 +
                                 {{8{bus_data_i[7]}}, bus_data_i};
                        pq_br <= 1'b1;
                        pq_int <= 1'b0;
                        pq_us <= 1'b0;
                        pbm_q <= 8'h80;
                        pq_hi <= 1'b0;
                        pq_push <= 1'b1;
                        state <= S_PUSHQ;
                    end else if (take) begin
                        pc <= pc + 16'h1 +
                              {{8{bus_data_i[7]}}, bus_data_i};
                        state <= S_FETCH;
                    end else state <= S_FETCH;
                end

                S_LREL_H: begin
                    data_q <= bus_data_i;
                    pc <= pc + 16'h1;
                    state <= S_LREL_L;
                end

                S_LREL_L: begin
                    pc <= pc + 16'h1;
                    take = f_branch(cond, cc);
                    if (op == O_BSR) begin
                        // pc (pre-advance) = offset lo byte; base = pc + 1
                        ea_q  = pc + 16'h1 + {data_q, bus_data_i};
                        pq_br <= 1'b1;
                        pq_int <= 1'b0;
                        pq_us <= 1'b0;
                        pbm_q <= 8'h80;
                        pq_hi <= 1'b0;
                        pq_push <= 1'b1;
                        state <= S_PUSHQ;
                    end else if (take) begin
                        pc <= pc + 16'h1 + {data_q, bus_data_i};
                        state <= S_FETCH;
                    end else state <= S_FETCH;
                end

                // ---------------- operand read / execute ----------------
                S_RD: begin
                    exec_alu8(bus_data_i);
                    state <= S_FETCH;
                end

                S_RD_H: begin
                    data_q <= bus_data_i;
                    state <= S_RD_L;
                end

                S_RD_L: begin
                    r16v = {data_q, bus_data_i};
                    exec_alu16(r16v);
                    state <= S_FETCH;
                end

                // 8-bit store: N/Z from the stored byte, V cleared
                // (6809 STA/STB rule; C, H, I unaffected)
                S_WR: begin
                    cc[FN] <= acc ? a[7] : b[7];
                    cc[FZ] <= ((acc ? a : b) == 8'h00);
                    cc[FV] <= 1'b0;
                    state <= S_FETCH;
                end

                S_WR_H: begin
                    // STS/STY/STU/STD: N, Z from the stored value, V=0
                    case (op)
                        O_STD: begin
                            cc[FN] <= a[7];
                            cc[FZ] <= ({a, b} == 16'h0);
                        end
                        O_STX: begin
                            cc[FN] <= x[15];
                            cc[FZ] <= (x == 16'h0);
                        end
                        O_STY: begin
                            cc[FN] <= y[15];
                            cc[FZ] <= (y == 16'h0);
                        end
                        O_STU: begin
                            cc[FN] <= u[15];
                            cc[FZ] <= (u == 16'h0);
                        end
                        default: begin   // O_STS
                            cc[FN] <= s[15];
                            cc[FZ] <= (s == 16'h0);
                        end
                    endcase
                    cc[FV] <= 1'b0;
                    state <= S_WR_L;
                end

                S_WR_L: state <= S_FETCH;

                // ---------------- RMW ----------------
                S_RMW_R: begin
                    data_q <= bus_data_i;
                    state <= S_RMW_E;
                end

                S_RMW_E: begin
                    rres = f_rmw(op, data_q, cc[FC]);
                    rmw_q <= rres[7:0];
                    cc[FC] <= rres[9];
                    cc[FV] <= rres[8];
                    cc[FN] <= rres[7];
                    cc[FZ] <= (rres[7:0] == 8'h00);
                    state <= S_RMW_W;
                end

                S_RMW_W: state <= S_FETCH;

                // ---------------- single push/pull ----------------
                S_PUSH: begin
                    s <= s - 16'h1;
                    state <= S_FETCH;
                end

                S_PULL: begin
                    if (acc) a <= bus_data_i; else b <= bus_data_i;
                    s <= s + 16'h1;
                    state <= S_FETCH;
                end

                // ---------------- masked push queue ----------------
                S_PUSHQ: begin
                    if (pq_us) u <= u - 16'h1;
                    else s <= s - 16'h1;
                    if (pq_hi) begin
                        pq_hi <= 1'b0;
                        if (pbm_q == (8'h01 << pq_ridx)) queue_done();
                        else state <= S_PUSHQ;
                        pbm_q[pq_ridx] <= 1'b0;
                    end else if (pq_is16(pq_ridx)) begin
                        pq_hi <= 1'b1;
                        state <= S_PUSHQ;
                    end else begin
                        if (pbm_q == (8'h01 << pq_ridx)) queue_done();
                        else state <= S_PUSHQ;
                        pbm_q[pq_ridx] <= 1'b0;
                    end
                end

                // ---------------- RTI ----------------
                S_RTIQ: begin
                    s <= s + 16'h1;
                    cc <= bus_data_i;
                    pbm_q <= bus_data_i[FE] ? 8'hFE : 8'h80;
                    pq_push <= 1'b0;
                    pq_hi <= 1'b1;   // 16-bit regs pull high byte first
                    state <= S_PULLQ;
                end

                // ---------------- masked pull queue ----------------
                S_PULLQ: begin
                    apply_pull(bus_data_i);
                    if (pq_us) u <= u + 16'h1;
                    else s <= s + 16'h1;
                    if (pq_is16(pq_ridx)) begin
                        if (pq_hi) begin
                            // high byte done; low byte follows
                            pq_hi <= 1'b0;
                            state <= S_PULLQ;
                        end else begin
                            // low byte done: release the register
                            pq_hi <= 1'b1;   // next reg starts high
                            if (pbm_q == (8'h01 << pq_ridx))
                                state <= S_FETCH;
                            else state <= S_PULLQ;
                            pbm_q[pq_ridx] <= 1'b0;
                        end
                    end else begin
                        if (pbm_q == (8'h01 << pq_ridx)) state <= S_FETCH;
                        else state <= S_PULLQ;
                        pbm_q[pq_ridx] <= 1'b0;
                    end
                end

                // ---------------- subroutine plumbing ----------------
                S_JSR1: begin
                    s <= s - 16'h1;
                    state <= S_JSR2;
                end

                S_JSR2: begin
                    s <= s - 16'h1;
                    pc <= ea_q;
                    state <= S_FETCH;
                end

                S_RTS_H: begin
                    data_q <= bus_data_i;
                    s <= s + 16'h1;
                    state <= S_RTS_L;
                end

                S_RTS_L: begin
                    pc <= {data_q, bus_data_i};
                    s <= s + 16'h1;
                    state <= S_FETCH;
                end

                // ---------------- vectors / wait / sync ----------------
                S_VEC_L: begin
                    data_q <= bus_data_i;
                    state <= S_VEC_H;
                end

                S_VEC_H: begin
                    pc <= {data_q, bus_data_i};
                    state <= S_FETCH;
                end

                S_WAIT: begin
                    if (cwai_wake) begin
                        // CWAI frame already on the stack; waking into
                        // service sets live E (frame is on the stack)
                        cc[FE] <= 1'b1;
                        if (nmi_live) begin
                            vec_q <= VEC_NMI;
                            nmi_pend <= 1'b0;
                        end else if (firq_req) begin
                            vec_q <= VEC_FIRQ;
                            cc[FF] <= 1'b1;
                            cc[FI] <= 1'b1;
                        end else begin
                            vec_q <= VEC_IRQ;
                            cc[FI] <= 1'b1;
                        end
                        state <= S_VEC_L;
                    end
                end

                S_SYNCW: begin
                    if (sync_wake) begin
                        // an unmasked source: service it
                        frame_e <= !firq_req || nmi_live;
                        pq_int <= 1'b1;
                        pq_br <= 1'b0;
                        pq_us <= 1'b0;
                        cwai_flag <= 1'b0;
                        if (nmi_live) begin
                            vec_q <= VEC_NMI;
                            nmi_pend <= 1'b0;
                        end else if (firq_req) vec_q <= VEC_FIRQ;
                        else vec_q <= VEC_IRQ;
                        pbm_q <= (!firq_req || nmi_live) ? 8'hFF : 8'h81;
                        pq_hi <= 1'b0;
                        pq_push <= 1'b1;
                        state <= S_PUSHQ;
                    end else if (nmi_live || !firq_n || !irq_n) begin
                        // only masked sources pending: resume after SYNC
                        state <= S_FETCH;
                    end
                end

                default: state <= S_FETCH;
            endcase

            nmi_prev <= nmi_n;
            if (!nmi_n && nmi_prev) nmi_pend <= 1'b1;
        end
    end
    /* verilator lint_on BLKSEQ */

    // ------------------------------------------------------------------
    // Sequencer helper tasks (called only from the clocked block above)
    // ------------------------------------------------------------------
    task automatic queue_done();
        if (pq_int && !cwai_flag) begin
            // live E mirrors the frame type; SWI sets I and F live,
            // SWI2/SWI3 leave the masks unchanged (data sheet)
            cc[FE] = frame_e;
            if (vec_q == VEC_FIRQ) begin
                cc[FF] = 1'b1;
                cc[FI] = 1'b1;
            end else if (vec_q == VEC_IRQ) begin
                cc[FI] = 1'b1;
            end else if (vec_q == VEC_SWI) begin
                cc[FI] = 1'b1;
                cc[FF] = 1'b1;
            end
            state = S_VEC_L;
        end else if (pq_int && cwai_flag) begin
            state = S_WAIT;
        end else if (pq_br) begin
            pc = ea_q;
            state = S_FETCH;
        end else begin
            state = S_FETCH;
        end
    endtask

    task automatic exec_inherent();
        state = S_FETCH;
        case (op)
            O_NOP: ;
            O_SEX: begin
                t16 = {1'b0, {8{b[7]}}, b};
                a = t16[15:8];
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_MUL: begin
                prod = a * b;
                {a, b} = prod;
                cc[FZ] = (prod == 16'h0);
                cc[FC] = prod[7];
            end
            O_ABX: x = x + {8'h00, b};
            O_NEG, O_COM, O_LSR, O_ROR, O_ASR, O_ASL, O_ROL,
            O_DEC, O_INC, O_TST, O_CLR: begin
                // accumulator form (memory forms route through S_RMW_*)
                rres = f_rmw(op, acc ? a : b, cc[FC]);
                if (op != O_TST) begin
                    if (acc) a = rres[7:0]; else b = rres[7:0];
                end
                cc[FC] = rres[9];
                cc[FV] = rres[8];
                cc[FN] = rres[7];
                cc[FZ] = (rres[7:0] == 8'h00);
            end
            O_DAA: begin
                daa9 = f_daa(a, cc[FH], cc[FC]);
                a = daa9[7:0];
                cc[FC] = daa9[8];
                cc[FN] = daa9[7];
                cc[FZ] = (daa9[7:0] == 8'h00);
            end
            O_SYNC: state = S_SYNCW;
            O_RTI: state = S_RTIQ;
            O_RTS: state = S_RTS_H;
            O_SWI:  begin vec_q = VEC_SWI;  start_frame(8'hFF); end
            O_SWI2: begin vec_q = VEC_SWI2; start_frame(8'hFF); end
            O_SWI3: begin vec_q = VEC_SWI3; start_frame(8'hFF); end
            default: ;
        endcase
    endtask

    task automatic start_frame(input logic [7:0] mask);
        // NBAs: yosys formal mis-lowers blocking writes to regs that the
        // sequencer also updates with NBAs (frame pushed with pbm_q=00)
        frame_e <= 1'b1;
        pq_int <= 1'b1;
        pq_br <= 1'b0;
        cwai_flag <= 1'b0;
        pbm_q <= mask;
        pq_hi <= 1'b0;
        pq_us <= 1'b0;
        state <= S_PUSHQ;
        pq_push <= 1'b1;
    endtask

    task automatic route_mode(input mode_e m);
        // pc/ea_q use NBA so they override the caller's scheduled
        // pc <= pc + 16'h1 (last NBA on a reg wins at the commit point);
        // during the edge pc still holds the opcode address
        case (m)
            S2_IMM8: state = S_IMM;
            S2_IMM16: begin
                ea_q <= pc + 16'h1;     // immediate word address
                pc <= pc + 16'h3;       // opcode + 2 immediate bytes
                state <= S_RD_H;
            end
            S2_DIR: state = S_DIR;
            S2_EXT: state = S_EXT_L;
            S2_IDX: state = S_PB;
            S2_REL: state = S_REL;
            S2_LREL: state = S_LREL_H;
            default: state = S_FETCH;
        endcase
    endtask

    task automatic route_ea();
        // pc/ea_q are blocking-updated by the caller before this call, so
        // pc already holds the post-instruction address here
        case (op)
            O_JMP: begin
                pc = ea_q;
                state = S_FETCH;
            end
            O_JSR: begin
                ret_q <= pc;   // pc = post-instruction (caller advanced it)
                pbm_q <= 8'h80;
                pq_hi <= 1'b0;
                pq_int <= 1'b0;
                pq_us <= 1'b0;
                pq_br <= 1'b0;
                state = S_JSR1;
            end
            O_LEAX: begin
                x = ea_q;
                cc[FZ] = (ea_q == 16'h0);
                state = S_FETCH;
            end
            O_LEAY: begin
                y = ea_q;
                cc[FZ] = (ea_q == 16'h0);
                state = S_FETCH;
            end
            O_LEAS: begin
                s = ea_q;
                nmi_arm = 1'b1;
                state = S_FETCH;
            end
            O_LEAU: begin
                u = ea_q;
                state = S_FETCH;
            end
            O_STA: state = S_WR;
            O_STD, O_STX, O_STY, O_STU, O_STS: state = S_WR_H;
            default: begin
                if (f_is_rmw(op)) state = S_RMW_R;
                else if (f_is16(op)) state = S_RD_H;
                else state = S_RD;
            end
        endcase
    endtask

    task automatic exec_imm8(input logic [7:0] imm);
        // imm = bus_data_i (data_q is NBA and not yet visible here)
        case (op)
            O_ANDCC: begin cc = cc & imm; state = S_FETCH; end
            O_ORCC: begin cc = cc | imm; state = S_FETCH; end
            O_TFR: begin do_tfr(imm, 1'b0); state = S_FETCH; end
            O_EXG: begin do_tfr(imm, 1'b1); state = S_FETCH; end
            O_PSHS: begin
                pbm_q <= imm; pq_hi <= 1'b0; pq_int <= 1'b0;
                pq_us <= 1'b0; pq_br <= 1'b0;
                pq_push <= 1'b1;
                // empty mask: no-op (queue machinery needs a set bit)
                state = (imm == 8'h00) ? S_FETCH : S_PUSHQ;
            end
            O_PSHU: begin
                pbm_q <= imm; pq_hi <= 1'b0; pq_int <= 1'b0;
                pq_us <= 1'b1; pq_br <= 1'b0;
                pq_push <= 1'b1;
                state = (imm == 8'h00) ? S_FETCH : S_PUSHQ;
            end
            O_PULS: begin
                // 16-bit registers sit big-endian on the stack: the
                // pulled-first byte (lowest address) is the HIGH byte
                pbm_q <= imm; pq_hi <= 1'b1; pq_int <= 1'b0;
                pq_us <= 1'b0; pq_br <= 1'b0;
                pq_push <= 1'b0;
                state = (imm == 8'h00) ? S_FETCH : S_PULLQ;
            end
            O_PULU: begin
                pbm_q <= imm; pq_hi <= 1'b1; pq_int <= 1'b0;
                pq_us <= 1'b1; pq_br <= 1'b0;
                pq_push <= 1'b0;
                state = (imm == 8'h00) ? S_FETCH : S_PULLQ;
            end
            O_CWAI: begin
                cc = cc & imm;
                cwai_flag <= 1'b1;
                frame_e <= 1'b1;
                pq_int <= 1'b1;
                pq_br <= 1'b0;
                pbm_q <= 8'hFF;
                pq_hi <= 1'b0;
                pq_us <= 1'b0;
                pq_push <= 1'b1;   // push order (PC first); was left 0 by PULS
                state = S_PUSHQ;
            end
            default: exec_alu8(imm);
        endcase
    endtask

    task automatic do_tfr(input logic [7:0] pb, input logic exg);
        logic [15:0] sv, dv;
        sv = get_tfr16(pb[7:4]);
        dv = get_tfr16(pb[3:0]);
        if (exg) begin
            put_tfr(pb[7:4], dv);
            put_tfr(pb[3:0], sv);
        end else begin
            put_tfr(pb[3:0], sv);
        end
    endtask

    function automatic logic [15:0] get_tfr16(input logic [3:0] r);
        case (r)
            4'h0: get_tfr16 = {a, b};
            4'h1: get_tfr16 = x;
            4'h2: get_tfr16 = y;
            4'h3: get_tfr16 = u;
            4'h4: get_tfr16 = s;
            // TFR/EXG execute in S_IMM, which has already advanced pc to
            // the post-instruction address with a blocking write
            4'h5: get_tfr16 = pc;
            4'h8: get_tfr16 = {8'h00, a};
            4'h9: get_tfr16 = {8'h00, b};
            4'hA: get_tfr16 = {8'h00, cc};
            4'hB: get_tfr16 = {8'h00, dp};
            default: get_tfr16 = 16'h0;
        endcase
    endfunction

    task automatic put_tfr(input logic [3:0] r, input logic [15:0] v);
        case (r)
            4'h0: {a, b} = v;
            4'h1: x = v;
            4'h2: y = v;
            4'h3: u = v;
            4'h4: s = v;
            4'h5: pc = v;
            4'h8: a = v[7:0];
            4'h9: b = v[7:0];
            4'hA: cc = v[7:0];
            4'hB: dp = v[7:0];
            default: ;
        endcase
    endtask

    task automatic exec_alu8(input logic [7:0] val);
        logic [7:0] av;
        av = acc ? a : b;
        case (op)
            O_LDA: begin
                if (acc) a = val; else b = val;
                cc[FN] = val[7];
                cc[FZ] = (val == 8'h00);
                cc[FV] = 1'b0;
            end
            O_AND, O_BIT: begin
                av = av & val;
                cc[FN] = av[7];
                cc[FZ] = (av == 8'h00);
                cc[FV] = 1'b0;
                if (op == O_AND) begin
                    if (acc) a = av; else b = av;
                end
            end
            O_ORA: begin
                av = av | val;
                cc[FN] = av[7];
                cc[FZ] = (av == 8'h00);
                cc[FV] = 1'b0;
                if (acc) a = av; else b = av;
            end
            O_EOR: begin
                av = av ^ val;
                cc[FN] = av[7];
                cc[FZ] = (av == 8'h00);
                cc[FV] = 1'b0;
                if (acc) a = av; else b = av;
            end
            O_ADD: begin
                t8 = f_add8(av, val, 1'b0);
                cc[FC] = t8[8];
                cc[FV] = f_vadd(av, val, t8[7:0]);
                cc[FH] = f_hcarry(av, val, 1'b0);
                cc[FN] = t8[7];
                cc[FZ] = (t8[7:0] == 8'h00);
                if (acc) a = t8[7:0]; else b = t8[7:0];
            end
            O_ADC: begin
                t8 = f_add8(av, val, cc[FC]);
                cc[FH] = f_hcarry(av, val, cc[FC]);   // old C, before update
                cc[FC] = t8[8];
                cc[FV] = f_vadd(av, val, t8[7:0]);
                cc[FN] = t8[7];
                cc[FZ] = (t8[7:0] == 8'h00);
                if (acc) a = t8[7:0]; else b = t8[7:0];
            end
            O_SUB, O_CMP: begin
                t8 = f_sub8(av, val, 1'b0);
                cc[FC] = t8[8];   // 6809 C = borrow
                cc[FV] = f_vsub(av, val, t8[7:0]);
                cc[FN] = t8[7];
                cc[FZ] = (t8[7:0] == 8'h00);
                if (op == O_SUB) begin
                    if (acc) a = t8[7:0]; else b = t8[7:0];
                end
            end
            O_SBC: begin
                t8 = f_sub8(av, val, cc[FC]);   // SBC subtracts C directly
                cc[FC] = t8[8];
                cc[FV] = f_vsub(av, val, t8[7:0]);
                cc[FN] = t8[7];
                cc[FZ] = (t8[7:0] == 8'h00);
                if (acc) a = t8[7:0]; else b = t8[7:0];
            end
            default: ;
        endcase
    endtask

    task automatic exec_alu16(input logic [15:0] val);
        logic [15:0] dv;
        dv = {a, b};
        case (op)
            O_LDD: begin
                {a, b} = val;
                cc[FN] = val[15];
                cc[FZ] = (val == 16'h0);
                cc[FV] = 1'b0;
            end
            O_LDX: begin
                x = val;
                cc[FN] = val[15];
                cc[FZ] = (val == 16'h0);
                cc[FV] = 1'b0;
            end
            O_LDY: begin
                y = val;
                cc[FN] = val[15];
                cc[FZ] = (val == 16'h0);
                cc[FV] = 1'b0;
            end
            O_LDU: begin
                u = val;
                cc[FN] = val[15];
                cc[FZ] = (val == 16'h0);
                cc[FV] = 1'b0;
            end
            O_LDS: begin
                s = val;
                cc[FN] = val[15];
                cc[FZ] = (val == 16'h0);
                cc[FV] = 1'b0;
                nmi_arm = 1'b1;
            end
            O_ADDD: begin
                t16 = f_add16(dv, val, 1'b0);
                {a, b} = t16[15:0];
                cc[FC] = t16[16];
                cc[FV] = f_vadd16(dv, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_SUBD: begin
                t16 = f_sub16(dv, val, 1'b0);
                {a, b} = t16[15:0];
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(dv, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_CMPD: begin
                t16 = f_sub16(dv, val, 1'b0);
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(dv, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_CMPX: begin
                t16 = f_sub16(x, val, 1'b0);
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(x, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_CMPY: begin
                t16 = f_sub16(y, val, 1'b0);
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(y, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_CMPU: begin
                t16 = f_sub16(u, val, 1'b0);
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(u, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            O_CMPS: begin
                t16 = f_sub16(s, val, 1'b0);
                cc[FC] = t16[16];
                cc[FV] = f_vsub16(s, val, t16[15:0]);
                cc[FN] = t16[15];
                cc[FZ] = (t16[15:0] == 16'h0);
            end
            default: ;
        endcase
    endtask

    task automatic apply_pull(input logic [7:0] v);
        case (pq_ridx)
            3'd7: pc = pq_hi ? {v, pc[7:0]} : {pc[15:8], v};
            3'd6: begin
                if (pq_us) s = pq_hi ? {v, s[7:0]} : {s[15:8], v};
                else       u = pq_hi ? {v, u[7:0]} : {u[15:8], v};
            end
            3'd5: y = pq_hi ? {v, y[7:0]} : {y[15:8], v};
            3'd4: x = pq_hi ? {v, x[7:0]} : {x[15:8], v};
            3'd3: dp = v;
            3'd2: b = v;
            3'd1: a = v;
            default: cc = v;   // CC (PULS/PULU cc; RTI pre-handles its own)
        endcase
    endtask

    function automatic logic [15:0] stored16();
        case (op)
            O_STD: stored16 = {a, b};
            O_STX: stored16 = x;
            O_STY: stored16 = y;
            O_STU: stored16 = u;
            default: stored16 = s;
        endcase
    endfunction

`ifdef FORMAL
    `include "motorola_6809_props.sv"
    `include "motorola_6809_cover_setup.sv"
`endif
endmodule
